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

enum ControllerFaults {
  ChargeMOSShortCircuit(30),
  AntiReverseMOSShort(29),

  /// PV Reverse Polarity. The controller will not operate if the PV wires are switched.
  /// Wire them correctly to resume normal controller operation.
  SolarPanelReverselyConnected(28),
  SolarPanelWorkingPointOverVoltage(27),
  SolarPanelCounterCurrent(26),

  /// PV Overvoltage. If the PV voltage is larger than maximum input open voltage 100VDC.
  /// PV will remain disconnected until the voltage drops below 100VDC.
  PhotovoltaicInputSideOverVoltage(25),

  /// PV Array Short Circuit. When PV short circuit occurs, the controller will stop
  /// charging. Clear it to resume normal operation.
  PhotovoltaicInputSideShortCircuit(24),

  /// PV Overcurrent. The controller will limit the battery chgarging current to the
  /// maximum battery current rating. Therefore, an over-sized solar array will not operate at peak power.
  PhotovoltaicInputOverpower(23),
  AmbientTemperatureTooHigh(22),

  /// Over-Temperature. If the temperature of the controller heat sink exceeds 65 C,
  /// the controller will automatically start reducing the charging current. The controller will
  /// shut down when the temperature exceeds 85 C.
  ControllerTemperatureTooHigh(21),

  /// Load Overload. If the current exceeds the maximum load current rating 1.05 times,
  /// the controller will disconnect the load. Overloading must be cleared up by reducing the
  /// load and restarting the controller.
  LoadOverpowerOrLoadOverCurrent(20),

  /// Load Short Circuit. Fully protected against the load wiring short-circuit. Once the load
  /// short (more than quadruple rate current), the load short protection will start automatically.
  /// After 5 automatic load reconnect attempts, the faults must be cleared by restarting the controller.
  LoadShortCircuit(19),
  BatteryUnderVoltageWarning(18),
  BatteryOverVoltage(17),
  BatteryOverDischarge(16),
  ;

  final int _bit;

  const ControllerFaults(this._bit);

  bool _isPresent(int modbusValue) {
    final probe = 1 << _bit;
    return (modbusValue & probe) != 0;
  }

  static Set<ControllerFaults> fromModbus(int modbusValue) {
    return values.where((it) => it._isPresent(modbusValue)).toSet();
  }
}

class RenogyStatus {
  /// Whether the street light is on or off
  bool streetLightOn = false;

  /// street light brightness value, 0..100 in %
  int streetLightBrightness = 0;

  /// charging state (if known)
  ChargingState? chargingState = null;

  /// current faults, empty if none.
  Set<ControllerFaults> faults = {};

  Map toJson() => {
    "streetLightOn": streetLightOn,
    "streetLightBrightness": streetLightBrightness,
    "chargingState": chargingState?.name,
    "faults": faults.map((e) => e.name).join(",")
  };

  @override
  String toString() => 'RenogyStatus${toJson().toString()}';
}

/// Historical data summary
class HistoricalData {
  /// Total number of operating days
  int daysUp = 0;
  /// Total number of battery over-discharges
  int batteryOverDischargeCount = 0;
  /// Total number of battery full-charges.
  int batteryFullChargeCount = 0;
  /// Total charging amp-hrs of the battery.
  int totalChargingBatteryAH = 0;
  /// Total discharging amp-hrs of the battery. mavi: probably only applicable to inverters, 0 for controller.
  int totalDischargingBatteryAH = 0;
  /// cumulative power generation in Wh. Probably only applies to controller, will be 0 for inverter.
  int cumulativePowerGenerationWH = 0;
  /// cumulative power consumption in Wh. mavi: probably only applicable to inverters, 0 for controller.
  int cumulativePowerConsumptionWH = 0;

  Map toJson() => {
    "daysUp": daysUp,
    "batteryOverDischargeCount": batteryOverDischargeCount,
    "batteryFullChargeCount": batteryFullChargeCount,
    "totalChargingBatteryAH": totalChargingBatteryAH,
    "totalDischargingBatteryAH": totalDischargingBatteryAH,
    "cumulativePowerGenerationWH": cumulativePowerGenerationWH,
    "cumulativePowerConsumptionWH": cumulativePowerConsumptionWH
  };

  @override
  String toString() => 'HistoricalData${toJson().toString()}';
}
