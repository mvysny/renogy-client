import 'dart:io';

import 'package:renogy_client/clients/dummy_renogy_client.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:test/test.dart';

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
}
