import 'dart:convert';

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

  Map<String, Object?> toJson() => {
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

  Map<String, Object?> toJson() => {
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

/// Daily statistics.
class DailyStats {
  /// Battery's min. voltage of the current day, V. Precision: 1 decimal points.
  double batteryMinVoltage = 0;

  /// Battery's max. voltage of the current day, V. Precision: 1 decimal points.
  double batteryMaxVoltage = 0;

  /// Max. charging current of the current day, A. Probably applies to controller only. Precision: 2 decimal points.
  double maxChargingCurrent = 0;

  /// Max. discharging current of the current day, A. mavi: probably only applies to inverter; will be 0 for controller. Precision: 2 decimal points.
  double maxDischargingCurrent = 0;

  /// Max. charging power of the current day, W. mavi: probably only applies to controller; will be 0 for inverter.
  int maxChargingPower = 0;

  /// Max. discharging power of the current day, W. mavi: probably only applies to inverter; will be 0 for controller.
  int maxDischargingPower = 0;

  /// Charging amp-hrs of the current day, Ah. mavi: probably only applies to controller; will be 0 for inverter.
  int chargingAh = 0;

  /// Discharging amp-hrs of the current day, Ah. mavi: probably only applies to inverter; will be 0 for controller.
  int dischargingAh = 0;

  /// Power generation of the current day, Wh. Probably only applies to controller.
  int powerGenerationWh = 0;

  /// Power consumption of the current day, Wh. Probably only applies to inverter.
  int powerConsumptionWh = 0;

  Map<String, Object?> toJson() => {
        "batteryMinVoltage": batteryMinVoltage,
        "batteryMaxVoltage": batteryMaxVoltage,
        "maxChargingCurrent": maxChargingCurrent,
        "maxDischargingCurrent": maxDischargingCurrent,
        "maxChargingPower": maxChargingPower,
        "maxDischargingPower": maxDischargingPower,
        "chargingAh": chargingAh,
        "dischargingAh": dischargingAh,
        "powerGenerationWh": powerGenerationWh,
        "powerConsumptionWh": powerConsumptionWh
      };

  @override
  String toString() =>
      "DailyStats(batteryMinVoltage=$batteryMinVoltage V, batteryMaxVoltage=$batteryMaxVoltage V, maxChargingCurrent=$maxChargingCurrent A, maxDischargingCurrent=$maxDischargingCurrent A, maxChargingPower=$maxChargingPower W, maxDischargingPower=$maxDischargingPower W, chargingAmpHours=$chargingAh AH, dischargingAmpHours=$dischargingAh AH, powerGeneration=$powerGenerationWh WH, powerConsumption=$powerConsumptionWh WH)";
}

class PowerStatus {
  /// Current battery capacity value (state of charge), 0..100%
  int batterySOC = 0;

  /// battery voltage in V. Precision: 1 decimal points.
  double batteryVoltage = 0;

  /// charging current (to battery), A. Precision: 2 decimal points.
  double chargingCurrentToBattery = 0;

  /// battery temperature in °C
  int batteryTemp = 0;

  /// controller temperature in °C
  int controllerTemp = 0;

  /// Street light (load) voltage in V. Precision: 1 decimal points.
  double loadVoltage = 0;

  /// Street light (load) current in A. Precision: 2 decimal points.
  double loadCurrent = 0;

  /// Street light (load) power, in W
  int loadPower = 0;

  /// solar panel voltage, in V. Precision: 1 decimal points.
  double solarPanelVoltage = 0;

  /// Solar panel current (to controller), in A. Precision: 2 decimal points.
  double solarPanelCurrent = 0;

  /// charging power, in W
  int solarPanelPower = 0;

  Map<String, Object?> toJson() => {
        "batterySOC": batterySOC,
        "batteryVoltage": batteryVoltage,
        "chargingCurrentToBattery": chargingCurrentToBattery,
        "batteryTemp": batteryTemp,
        "controllerTemp": controllerTemp,
        "loadVoltage": loadVoltage,
        "loadCurrent": loadCurrent,
        "loadPower": loadPower,
        "solarPanelVoltage": solarPanelVoltage,
        "solarPanelCurrent": solarPanelCurrent,
        "solarPanelPower": solarPanelPower
      };

  @override
  String toString() =>
      "PowerStatus(batterySOC=$batterySOC%, batteryVoltage=$batteryVoltage V, chargingCurrentToBattery=$chargingCurrentToBattery A, batteryTemp=$batteryTemp°C, controllerTemp=$controllerTemp°C, loadVoltage=$loadVoltage V, loadCurrent=$loadCurrent A, loadPower=$loadPower W, solarPanelVoltage=$solarPanelVoltage V, solarPanelCurrent=$solarPanelCurrent A, solarPanelPower=$solarPanelPower W)";
}

enum ProductType {
  Controller(0),
  Inverter(1);

  final int modbusValue;

  const ProductType(this.modbusValue);
}

/// The static system information: hw/sw version, specs etc.
class SystemInfo {
  /// max. voltage supported by the system: 12V/24V/36V/48V/96V; 0xFF=automatic recognition of system voltage
  int maxVoltage = 0;

  /// rated charging current in A: 10A/20A/30A/45A/60A
  int ratedChargingCurrent = 0;

  /// rated discharging current, 10A/20A/30A/45A/60A
  int ratedDischargingCurrent = 0;

  /// product type
  ProductType? productType = null;

  /// the controller's model
  String productModel = "";

  /// Vmajor.minor.bugfix
  String softwareVersion = "";

  /// Vmajor.minor.bugfix
  String hardwareVersion = "";

  /// serial number, 4 bytes formatted as a hex string, e.g. `1501FFFF`,
  //  * indicating it's the 65535th (hexadecimal FFFFH) unit produced in Jan. of 2015.
  String serialNumber = "";

  Map<String, Object?> toJson() => {
        "maxVoltage": maxVoltage,
        "ratedChargingCurrent": ratedChargingCurrent,
        "ratedDischargingCurrent": ratedDischargingCurrent,
        "productType": productType?.name,
        "productModel": productModel,
        "softwareVersion": softwareVersion,
        "hardwareVersion": hardwareVersion,
        "serialNumber": serialNumber
      };

  @override
  String toString() =>
      "SystemInfo(maxVoltage=$maxVoltage V, ratedChargingCurrent=$ratedChargingCurrent A, ratedDischargingCurrent=$ratedDischargingCurrent A, productType=$productType, productModel=$productModel, softwareVersion=$softwareVersion, hardwareVersion=$hardwareVersion, serialNumber=$serialNumber)";
}

/// Thrown when Renogy returns a failure.
class RenogyException implements Exception {
  /// the message
  final String message;

  /// the error code as received from Renogy. See [fromCode] for a list of
  //  defined error codes. May be null if thrown because the response was mangled.
  final int? code;

  RenogyException(this.message, { this.code });

  @override
  String toString() => "RenogyException: $code $message";

  static RenogyException fromCode(int code) {
    String message = "Unknown";
    switch(code) {
      case 1: message = "Function code not supported"; break;
      case 2: message = "PDU start address is not correct or PDU start address + data length"; break;
      case 3: message = "Data length in reading or writing register is too large"; break;
      case 4: message = "Client fails to read or write register"; break;
      case 5: message = "Data check code sent by server is not correct"; break;
    }
    return RenogyException(message, code: code);
  }
}

/// Contains all data which can be pulled from the Renogy device.
class RenogyData {
  late SystemInfo systemInfo;
  late PowerStatus powerStatus;
  late DailyStats dailyStats;
  late HistoricalData historicalData;
  late RenogyStatus status;

  Map<String, Object?> toJson() => {
    "systemInfo": systemInfo,
    "powerStatus": powerStatus,
    "dailyStats": dailyStats,
    "historicalData": historicalData,
    "status": status
  };

  String toJsonString({ bool prettyPrint = true}) => JsonEncoder.withIndent(prettyPrint ? "  " : null).convert(this);

  @override
  String toString() => toJsonString();
}

abstract class RenogyClient {
  /// Retrieves the [SystemInfo] from the device.
  SystemInfo getSystemInfo();

  /// Retrieves all current data from a Renogy device. Usually [SystemInfo] is only
  /// fetched once and then cached; it can be passed in as [cachedSystemInfo]
  /// to avoid repeated retrieval.
  ///
  /// If [cachedSystemInfo] is not null, this information will not be fetched.
  ///
  /// Throws [RenogyException] if the data retrieval fails
  RenogyData getAllData({SystemInfo? cachedSystemInfo});

  /// Closes the client. The client must not be used afterwards.
  void close();
}
