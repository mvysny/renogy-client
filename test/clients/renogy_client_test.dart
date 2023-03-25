import 'package:renogy_client/clients/renogy_client.dart';
import 'package:test/test.dart';

void main() {
  test('toString', () {
    expect(
        (RenogyStatus()
              ..chargingState = ChargingState.BoostChargingMode
              ..faults = {ControllerFaults.AmbientTemperatureTooHigh})
            .toString(),
        "{streetLightOn: false, streetLightBrightness: 0, chargingState: BoostChargingMode, faults: AmbientTemperatureTooHigh}");
  });
}
