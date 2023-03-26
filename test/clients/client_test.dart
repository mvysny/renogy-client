import 'dart:io';
import 'dart:typed_data';

import 'package:renogy_client/clients/dummy_renogy_client.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/clients/renogy_modbus_client.dart';
import 'package:test/test.dart';

import '../utils/buffer.dart';

void main() {
  group('RenogyStatus', () {
    test('toString', () {
      expect(
          (RenogyStatus()
                ..chargingState = ChargingState.BoostChargingMode
                ..faults = {ControllerFaults.AmbientTemperatureTooHigh})
              .toString(),
          "RenogyStatus{streetLightOn: false, streetLightBrightness: 0, chargingState: BoostChargingMode, faults: AmbientTemperatureTooHigh}");
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
      final client = RenogyModbusClient(buffer);
      final Uint8List response = client.readRegister(0x0A, 0x02);
      buffer.expectWrittenBytes("0103000a0001a408");
      expect("181e", response.toHex());
    });
    test('readRegister000AErrorResponse', () {
      final buffer = Buffer();
      buffer.toReturnAdd("018302c0f1");
      final client = RenogyModbusClient(buffer);
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
      final client = RenogyModbusClient(buffer);
      final response = client.readRegister(0x0C, 16);
      buffer.expectWrittenBytes("0103000c0008840f");
      expect("202020204d5434383330202020202020", response.toHex());
    });
  });
}
