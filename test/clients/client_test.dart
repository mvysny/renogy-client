import 'dart:io';
import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:renogy_client/clients/dummy_renogy_client.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/clients/renogy_modbus_client.dart';
import 'package:test/test.dart';

import '../utils/buffer.dart';
import 'dummy_data.dart';

void main() {
  group('RenogyStatus', () {
    test('toString', () {
      expect(
          (RenogyStatus()
                ..chargingState = ChargingState.BoostChargingMode
                ..faults = {ControllerFaults.AmbientTemperatureTooHigh})
              .toString(),
          "RenogyStatus{streetLightOn: false, streetLightBrightness: 0, chargingState: BoostChargingMode, faults: [AmbientTemperatureTooHigh]}");
    });
    test('toJson', () {
      expect('{"systemInfo":{"maxVoltage":24,"ratedChargingCurrent":40,"ratedDischargingCurrent":40,"productType":"Controller","productModel":"RENOGY ROVER","softwareVersion":"v1.2.3","hardwareVersion":"v4.5.6","serialNumber":"1501FFFF"},"powerStatus":{"batterySOC":100,"batteryVoltage":25.6,"chargingCurrentToBattery":2.3,"batteryTemp":23,"controllerTemp":23,"loadVoltage":0.0,"loadCurrent":0.0,"loadPower":0,"solarPanelVoltage":60.2,"solarPanelCurrent":4.2,"solarPanelPower":252},"dailyStats":{"batteryMinVoltage":25.0,"batteryMaxVoltage":28.0,"maxChargingCurrent":10.0,"maxDischargingCurrent":10.0,"maxChargingPower":240,"maxDischargingPower":240,"chargingAh":100,"dischargingAh":100,"powerGenerationWh":0,"powerConsumptionWh":0},"historicalData":{"daysUp":20,"batteryOverDischargeCount":1,"batteryFullChargeCount":20,"totalChargingBatteryAH":2000,"totalDischargingBatteryAH":2000,"cumulativePowerGenerationWH":2000,"cumulativePowerConsumptionWH":2000},"status":{"streetLightOn":false,"streetLightBrightness":0,"chargingState":"MpptChargingMode","faults":["ControllerTemperatureTooHigh"]}}',
        dummyRenogyData.toJsonString(prettyPrint: false));
    });
  });
  group('ControllerFaults', () {
    test('fromModbus()', () {
      expect(ControllerFaults.fromModbus(0), <ControllerFaults>{});
      expect({ControllerFaults.PhotovoltaicInputSideShortCircuit, ControllerFaults.BatteryOverDischarge}, ControllerFaults.fromModbus(0x01010000));
    });
  });
  group('DummyRenogyClient', () {
    test('dummy', () {
      final client = DummyRenogyClient();
      client.getAllData();
      client.getAllData();
      sleep(Duration(milliseconds: 10));
      client.getAllData();
    });
  });
  group('RenogyModbusClient', () {
    test('readRegister000ANormalResponse', () {
      final buffer = Buffer();
      buffer.toReturnAdd("010302181e324c");
      final client = RenogyModbusClient(buffer, Duration.zero);
      final Uint8List response = client.readRegister(0x0A, 0x02);
      buffer.expectWrittenBytes("0103000a0001a408");
      expect("181e", HEX.encode(response.toList()));
    });
    test('readRegister000AErrorResponse', () {
      final buffer = Buffer();
      buffer.toReturnAdd("018302c0f1");
      final client = RenogyModbusClient(buffer, Duration.zero);
      try {
        client.readRegister(0x0A, 0x02);
        fail("Expected to fail with clients.RenogyException");
      } on RenogyException catch (e) {
        // okay
        expect(e.message, "0x02: PDU start address is not correct or PDU start address + data length");
      }
      buffer.expectWrittenBytes("0103000a0001a408");
    });
    test('readRegister000CNormalResponse', () {
      final buffer = Buffer();
      buffer.toReturnAdd("010310202020204d5434383330202020202020ee98");
      final client = RenogyModbusClient(buffer, Duration.zero);
      final response = client.readRegister(0x0C, 16);
      buffer.expectWrittenBytes("0103000c0008840f");
      expect("202020204d5434383330202020202020", HEX.encode(response.toList()));
    });
    test('testReadDailyStats', () {
      final buffer = Buffer();
      // The 4th and 5th bytes 0070H indicate the current day's min. battery voltage: 0070H * 0.1 = 112 * 0.1 = 11.2V
      // The 6th and 7th bytes 0084H indicate the current day's max. battery voltage: 0084H * 0.1 = 132 * 0.1 = 13.2V
      // The 8th and 9th bytes 00D8H indicate the current day's max. charging current: 00D8H * 0.01 = 216 * 0.01 = 2.16V
      // then max discharge current: 0
      // then max charging power: 10
      // max discharging power: 0
      // 0608H are the current day's charging amp-hrs (decimal 1544AH);
      // 0810H are the current day's discharging amp-hrs (decimal 2064AH)
      buffer.toReturnAdd("0103140070008400d80000000a00000608081000700084ebde");
      final client = RenogyModbusClient(buffer, Duration.zero);
      final dailyStats = client.getDailyStats();
      buffer.expectWrittenBytes("0103010b000ab5f3");
      final expectedStats = DailyStats()
        ..batteryMinVoltage = 11.2
        ..batteryMaxVoltage = 13.2
        ..maxChargingCurrent = 2.16
        ..maxDischargingCurrent = 0
        ..maxChargingPower = 10
        ..maxDischargingPower = 0
        ..chargingAh = 1544
        ..dischargingAh = 2064
        ..powerGenerationWh = 112
        ..powerConsumptionWh = 132;
      expect(dailyStats, expectedStats);
    });
  });
}
