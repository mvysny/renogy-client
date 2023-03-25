import 'package:collection/collection.dart';

enum ChargingState {
  /// Charging is deactivated. There is no current/voltage detected from the solar panels.
  /// This happens when it's night outside, or the solar array is disconnected:
  /// either the fuse tripped, or perhaps the cables are broken.
  ChargingDeactivated(0),
  ChargingActivated(1),

  /// Bulk Charging. This algorithm is used for day to day charging. It uses 100% of available solar
  /// power to recharge the battery and is equivalent to constant current. In this stage the battery
  /// voltage has not yet reached constant voltage (Equalize or Boost), the controller operates in
  /// constant current mode, delivering its maximum current to the batteries (MPPT Charging).
  MpptChargingMode(2),

  /// Equalization: Is carried out every 28 days of the month. It is intentional overcharging of
  /// the battery for a controlled period of time. Certain types of batteries benefit from periodic
  /// equalizing charge, which can stir the electrolyte, balance battery voltage and complete
  /// chemical reaction. Equalizing charge increases the battery voltage, higher than the standard
  /// complement voltage, which gasifies the battery electrolyte.
  ///
  /// Should not be used for AGM batteries.
  EqualizingChargingMode(3),

  /// Constant Charging Mode. When the battery reaches the constant voltage set point, the controller
  /// will start to operate in constant charging mode, where it is no longer MPPT charging. The current
  /// will drop gradually. This has two stages, equalize and boost and they are not carried out
  /// constantly in a full charge process to avoid too much gas precipitation or overheating of the
  /// battery. See [EqualizingChargingMode] for more details.
  ///
  /// Boost stage maintains a charge for 2 hours by default. The user
  /// can adjust the constant time and preset value of boost per their demand.
  BoostChargingMode(4),

  /// After the constant voltage stage ([BoostChargingMode]/[EqualizingChargingMode]), the controller will reduce the battery voltage
  /// to a float voltage set point. Once the battery is fully charged, there will be no more chemical
  /// reactions and all the charge current would turn into heat or gas. Because of this,
  /// the charge controller will reduce the voltage charge to smaller quantity, while lightly charging
  /// the battery. The purpose for this is to offset the power consumption while maintaining a full
  /// battery storage capacity. In the event that a load drawn from the battery exceeds the charge
  /// current, the controller will no longer be able to maintain the battery to a Float set point and the
  /// controller will end the float charge stage and refer back to bulk charging ([MpptChargingMode]).
  FloatingChargingMode(5),

  /// Current limiting (overpower)
  CurrentLimiting(6);

  /// modbus value
  final int value;

  const ChargingState(this.value);

  static ChargingState? fromModbus(int value) {
    return values.firstWhereOrNull((element) => element.value == value);
  }
}
