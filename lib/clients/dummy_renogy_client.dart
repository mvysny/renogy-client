import 'dart:math';

import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/utils/time_utils.dart';
import 'package:renogy_client/utils/utils.dart';

/// Returns random data, emulating stuff returned by an actual Renogy Client
class DummyRenogyClient implements RenogyClient {
  ///  max rated amperage of the solar panel array
  double maxSolarPanelVoltage = 61;

  /// max rated voltage of the solar panel array
  double maxSolarPanelAmperage = 5;

  ///Adjustment percentage per hour-of-day, so that we generate 0% at midnight. Makes the
  /// dummy data more realistic.
  final _solarPanelGenerationPercentagePerHour = <double>[
    0,
    0,
    0,
    0,
    0,
    0,
    0.1,
    0.3,
    0.6,
    0.75,
    0.8,
    0.8,
    0.85,
    0.95,
    0.8,
    0.75,
    0.5,
    0.3,
    0.1,
    0,
    0,
    0,
    0,
    0
  ];

  @override
  SystemInfo getSystemInfo() => SystemInfo()
    ..maxVoltage = 24
    ..ratedChargingCurrent = 40
    ..ratedDischargingCurrent = 40
    ..productType = ProductType.Controller
    ..productModel = "RENOGY ROVER"
    ..softwareVersion = "v1.2.3"
    ..hardwareVersion = "v4.5.6"
    ..serialNumber = "1501FFFF";

  /// When the "device" was powered up (=when this class was created).
  final _poweredOnAt = DateTime.now();
  var _lastDailyStatsRetrievedAt = DateTime.now();
  LocalDate? _lastDailyStatsRetrievedAtDay;
  double _totalChargingBatteryAH = 0;
  double _cumulativePowerGenerationWH = 0;
  DailyStats? _lastDailyStats;
  double _lastDailyStatsChargingAh = 0;
  double _lastDailyStatsPowerGenerationWh = 0;

  DailyStats _getDailyStats() => _lastDailyStats!;

  HistoricalData _getHistoricalData() {
    final daysUp = (DateTime.now().difference(_poweredOnAt)).inDays + 1;
    return HistoricalData()
      ..daysUp = daysUp
      ..totalChargingBatteryAH = _totalChargingBatteryAH.toInt()
      ..cumulativePowerGenerationWH = _cumulativePowerGenerationWH.toInt();
  }

  @override
  RenogyData getAllData({SystemInfo? cachedSystemInfo}) {
    final systemInfo = cachedSystemInfo ?? getSystemInfo();
    // always local date since we calculate the generation percentage off it.
    final now = DateTime.now();

    // generate dummy power data flowing from the solar panels; calculate the rest of the values
    final solarPanelVoltage = random.nextDoubleRange(
        maxSolarPanelVoltage * 0.66, maxSolarPanelVoltage);
    var solarPanelCurrent = random.nextDoubleRange(
        maxSolarPanelAmperage / 2, maxSolarPanelAmperage);
    // adjust the generated power according to the hour-of-day, so that we won't generate 100% power at midnight :-D
    solarPanelCurrent *= _solarPanelGenerationPercentagePerHour[now.hour];
    // this is the most important value: this is the power (in Watts) the solar array is producing at this moment.
    final solarPanelPowerW = solarPanelVoltage * solarPanelCurrent;

    final batteryVoltage = random.nextDoubleRange(
        systemInfo.maxVoltage.toDouble(), systemInfo.maxVoltage * 1.19);
    // how much current flows into the battery at the moment.
    final currentToBattery = solarPanelPowerW / batteryVoltage;

    final dummyPowerStatus = PowerStatus()
      ..batterySOC = random.nextIntRange(66, 100)
      ..batteryVoltage = batteryVoltage
      ..chargingCurrentToBattery = currentToBattery
      ..batteryTemp = random.nextIntRange(18, 24)
      ..controllerTemp = random.nextIntRange(18, 24)
      ..loadVoltage = 0 // ignore the load, pretend there's none
      ..loadCurrent = 0
      ..loadPower = 0
      ..solarPanelVoltage = solarPanelVoltage
      ..solarPanelCurrent = solarPanelCurrent
      ..solarPanelPower = solarPanelPowerW.toInt();

    _updateStats(solarPanelPowerW, batteryVoltage);

    final dummyDailyStats = _getDailyStats();
    final dummyHistoricalData = _getHistoricalData();
    final dummyStatus = RenogyStatus()
      ..chargingState = ChargingState.MpptChargingMode;
    final dummyRenogyData = RenogyData()
      ..systemInfo = systemInfo
      ..powerStatus = dummyPowerStatus
      ..dailyStats = dummyDailyStats
      ..historicalData = dummyHistoricalData
      ..status = dummyStatus;
    return dummyRenogyData;
  }

  @override
  void close() {}

  /// Updates statistics. Now we can calculate [DailyStats] and [HistoricalData] correctly.
  ///
  /// [solarPanelPowerW] solar array produces this amount of watts now.
  /// [batteryVoltage] actual battery voltage.
  void _updateStats(double solarPanelPowerW, double batteryVoltage) {
    final currentToBattery = solarPanelPowerW / batteryVoltage;
    final now = DateTime.now();
    final today = now.getLocalDate();
    final millisSinceLastMeasurement =
        now.difference(_lastDailyStatsRetrievedAt);
    final double hoursSinceLastMeasurement =
        millisSinceLastMeasurement.inMilliseconds / 1000 / 60 / 60;
    final double ampHoursToBatterySinceLastMeasurement =
        currentToBattery * hoursSinceLastMeasurement;
    final energySinceLastMeasurementWh =
        solarPanelPowerW * hoursSinceLastMeasurement;

    _totalChargingBatteryAH += ampHoursToBatterySinceLastMeasurement;
    _cumulativePowerGenerationWH +=
        ampHoursToBatterySinceLastMeasurement * batteryVoltage;

    if (_lastDailyStats == null || today != _lastDailyStatsRetrievedAtDay) {
      _lastDailyStatsRetrievedAtDay = today;
      _lastDailyStats = DailyStats()
        ..batteryMinVoltage = batteryVoltage
        ..batteryMaxVoltage = batteryVoltage
        ..maxChargingCurrent = currentToBattery
        ..maxDischargingCurrent = 0
        ..maxChargingPower = solarPanelPowerW.toInt()
        ..maxDischargingPower = 0
        ..chargingAh = ampHoursToBatterySinceLastMeasurement.toInt()
        ..dischargingAh = 0
        ..powerGenerationWh = energySinceLastMeasurementWh.toInt()
        ..powerConsumptionWh = 0;
      _lastDailyStatsChargingAh = ampHoursToBatterySinceLastMeasurement;
      _lastDailyStatsPowerGenerationWh = energySinceLastMeasurementWh;
    } else {
      _lastDailyStatsChargingAh += ampHoursToBatterySinceLastMeasurement;
      _lastDailyStatsPowerGenerationWh += energySinceLastMeasurementWh;
      _lastDailyStats!.batteryMinVoltage =
          min(_lastDailyStats!.batteryMinVoltage, batteryVoltage);
      _lastDailyStats!.batteryMaxVoltage =
          max(_lastDailyStats!.batteryMaxVoltage, batteryVoltage);
      _lastDailyStats!.maxChargingCurrent =
          max(_lastDailyStats!.maxChargingCurrent, currentToBattery);
      _lastDailyStats!.maxChargingPower =
          max(_lastDailyStats!.maxChargingPower, solarPanelPowerW.toInt());
      _lastDailyStats!.chargingAh = _lastDailyStatsChargingAh.toInt();
      _lastDailyStats!.powerConsumptionWh =
          _lastDailyStatsPowerGenerationWh.toInt();
    }

    _lastDailyStatsRetrievedAt = now;
  }

  @override
  String toString() =>
      "DummyRenogyClient(maxSolarPanelVoltage=$maxSolarPanelVoltage, maxSolarPanelAmperage=$maxSolarPanelAmperage)";
}
