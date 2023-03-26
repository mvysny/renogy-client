
import 'dart:typed_data';

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
    if (deviceAddress < 0 || deviceAddress > 0xf7) throw ArgumentError.value(deviceAddress, "deviceAddress", "Device address must be 0x01..0xf7, 0x00 is a broadcast address to which all slaves respond but do not return commands");
  }

  /// Performs the ReadRegister call and returns the data returned. Internal, don't use.
  Uint8List readRegister(int startAddress, int noOfReadBytes) {
    final int noOfReadWords = noOfReadBytes ~/ 2;
    if (noOfReadWords < 1 || noOfReadWords > 0x7d) throw ArgumentError.value(noOfReadWords, "noOfReadWords", "must be 0x0001..0x007D");

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
    if (actual.length != 2) throw ArgumentError.value(actual, "actual", "must be of size 2");
    // for CRC, low byte is sent first, then the high byte.
    final actualUShort = ByteData.sublistView(actual).getUint16(0, Endian.little);
    if (actualUShort != expected) {
      throw RenogyException("Checksum mismatch: expected ${expected.toRadixString(16)} but got ${actualUShort.toRadixString(16)}");
    }
  }

  @override
  String toString() => 'RenogyModbusClient{deviceAddress: $deviceAddress}';
}
