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
  });
}
