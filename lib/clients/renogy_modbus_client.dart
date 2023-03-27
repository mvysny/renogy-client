
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:hex/hex.dart';
import 'package:logging/logging.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/utils/io.dart';
import 'package:renogy_client/utils/modbus_crc.dart';

/// Communicates with Renogy Rover over [io]. Doesn't close [io] on [close].
///
/// [deviceAddress] identifies the Renogy Rover if there are multiple Renogy devices on the network.
class RenogyModbusClient {
  final IO _io;
  final int deviceAddress;
  RenogyModbusClient(this._io, {this.deviceAddress = 1}) {
    RangeError.checkValueInInterval(deviceAddress, 0, 0xf7, "deviceAddress", "Device address must be 0x01..0xf7, 0x00 is a broadcast address to which all slaves respond but do not return commands");
  }

  /// Performs the ReadRegister call and returns the data returned. Internal, don't use.
  Uint8List readRegister(int startAddress, int noOfReadBytes) {
    if (!noOfReadBytes.isEven) throw ArgumentError.value(noOfReadBytes, "noOfReadBytes", "Must be even");
    final int noOfReadWords = noOfReadBytes ~/ 2;
    RangeError.checkValueInInterval(noOfReadWords, 1, 0x7d, "noOfReadWords");

    // prepare request
    final request = ByteData(8);
    request.setUint8(0, deviceAddress);
    request.setUint8(1, _commandReadRegister);
    request.setUint16(2, startAddress);
    request.setUint16(4, noOfReadWords);
    final crc = ModbusCRC();
    crc.update(request.buffer.asUint8List(0, 6));
    request.setUint16(6, crc.crc, Endian.little);
    _io.writeFully(request.buffer.asUint8List());

    // read response
    final Uint8List responseHeader = _io.readFully(3);
    if (responseHeader[0] != deviceAddress) {
      throw RenogyException("${startAddress.toRadixString(16)}: Invalid response: expected deviceAddress $deviceAddress but got ${responseHeader[0]}");
    }
    if (responseHeader[1] == 0x83) {
      // error response. First verify checksum.
      _verifyCRC(crcOf(responseHeader), _io.readFully(2));
      throw RenogyException.fromCode(responseHeader[2]);
    }
    if (responseHeader[1] != 3) {
      throw RenogyException("${startAddress.toRadixString(16)}: Unexpected response code: expected 3 but got ${responseHeader[1]}");
    }
    // normal response. Read the data.
    final dataLength = responseHeader[2];
    if(dataLength != noOfReadBytes) throw RenogyException("${startAddress.toRadixString(16)}: the call was expected to return $noOfReadBytes bytes but got $dataLength");

    if (dataLength < 1 || dataLength > 0xFA) {
      throw RenogyException("${startAddress.toRadixString(16)}: dataLength must be 0x01..0xFA but was $dataLength");
    }
    final Uint8List data = _io.readFully(dataLength.toInt());
    // verify the CRC
    _verifyCRC(crcOf2(responseHeader, data), _io.readFully(2));

    // all OK. Return the response
    return data;
  }

  static final int _commandReadRegister = 3;

  void _verifyCRC(int expected, Uint8List actual) {
    RangeError.checkValueInInterval(actual.length, 2, 2, "actual");
    // for CRC, low byte is sent first, then the high byte.
    final actualUShort = ByteData.sublistView(actual).getUint16(0, Endian.little);
    if (actualUShort != expected) {
      throw RenogyException("Checksum mismatch: expected ${expected.toRadixString(16)} but got ${actualUShort.toRadixString(16)}");
    }
  }

  @override
  String toString() => 'RenogyModbusClient{deviceAddress: $deviceAddress}';

  /// Retrieves the [SystemInfo] from the device.
  @override
  SystemInfo getSystemInfo() {
    _log.fine("getting system info");
    final result = SystemInfo();
    var register = readRegister(0x0A, 4);
    var data = ByteData.sublistView(register);
    result.maxVoltage = data.getUint8(0);
    result.ratedChargingCurrent = data.getUint8(1);
    result.ratedDischargingCurrent = data.getUint8(2);
    final productTypeNum = data.getUint8(3);
    result.productType = ProductType.values
        .firstWhereOrNull((e) => e.modbusValue == productTypeNum);

    register = readRegister(0x0C, 16);
    result.productModel = ascii.decode(register.toList()).trim();

    // software version/hardware version
    register = readRegister(0x0014, 8);
    data = ByteData.sublistView(register);
    result.softwareVersion =
        "V${data.getUint8(1)}.${data.getUint8(2)}.${data.getUint8(3)}";
    result.hardwareVersion =
        "V${data.getUint8(5)}.${data.getUint8(6)}.${data.getUint8(7)}";

    // serial number
    register = readRegister(0x0018, 4);
    result.serialNumber = HEX.encode(register.toList());
    return result;
  }

  /// Retrieves the current status of the device, e.g. current voltage on
  /// the solar panels.
  PowerStatus getPowerStatus() {
    _log.fine("getting power status");
    final register = readRegister(0x0100, 20);
    final data = ByteData.sublistView(register);

    final result = PowerStatus();
    result.batterySOC = data.getUint16(0);
    result.batteryVoltage = data.getUint16(2) / 10;
    // @todo in modbus spec examples, there's no chargingCurrentToBattery, and
    // batteryTemp is a WORD at 0x102 and controllerTemp is a WORD at 0x103 - check!
    result.chargingCurrentToBattery = data.getUint16(4) / 100;
    result.batteryTemp = data.getUint8(7);
    result.controllerTemp = data.getUint8(6);
    result.loadVoltage = data.getUint16(8) / 10;
    result.loadCurrent = data.getUint16(10) / 100;
    result.loadPower = data.getUint16(12);
    result.solarPanelVoltage = data.getUint16(14) / 10;
    result.solarPanelCurrent = data.getUint16(16) / 100;
    result.solarPanelPower = data.getUint16(18);

    return result;
  }

  /// Returns the daily statistics.
  DailyStats getDailyStats() {
    _log.fine("getting daily stats");
    final Uint8List register = readRegister(0x010B, 20);
    final ByteData result = ByteData.sublistView(register);
    final stats = DailyStats();
    stats.batteryMinVoltage = result.getUint16(0) / 10;
    stats.batteryMaxVoltage = result.getUint16(2) / 10;
    stats.maxChargingCurrent = result.getUint16(4) / 100;
    stats.maxDischargingCurrent = result.getUint16(6) / 100;
    stats.maxChargingPower = result.getUint16(8);
    stats.maxDischargingPower = result.getUint16(10);
    stats.chargingAh = result.getUint16(12);
    stats.dischargingAh = result.getUint16(14);
    // The manual says kWh/10000, however that value does not correspond to chargingAmpHours: chargingAmpHours=2 but this value is 5 for 24V system.
    // The example in manual says kWh which would simply be too much.
    // I'll make an educated guess here: it's Wh.
    stats.powerGenerationWh = result.getUint16(16);
    stats.powerConsumptionWh = result.getUint16(18);
    return stats;
  }

  /// Returns the historical data summary.
  HistoricalData getHistoricalData() {
    _log.fine("getting historical data");
    final register = readRegister(0x0115.toUShort(), 22.toUShort());
    final data = ByteData.sublistView(register);
    final result = HistoricalData();

    result.daysUp = data.getUint16(0);
    result.batteryOverDischargeCount = data.getUint16(2);
    result.batteryFullChargeCount = data.getUint16(4);
    result.totalChargingBatteryAH = data.getUint16(6);
    result.totalDischargingBatteryAH = data.getUint16(10);
    // The manual spec says kWh/10000; the manual example says kWh which doesn't make any sense.
    // I'll make an educated guess here: it's Wh.
    result.cumulativePowerGenerationWH = data.getUint32(14);
    result.cumulativePowerConsumptionWH = data.getUint32(18);
    return result;
  }

  static final _log = Logger((RenogyModbusClient).toString());
}
