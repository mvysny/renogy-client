import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/utils.dart';

/// Returns random data, emulating stuff returned by an actual Renogy Client
class DummyRenogyClient implements RenogyClient {
///  max rated amperage of the solar panel array
  double maxSolarPanelVoltage = 61;
  /// max rated voltage of the solar panel array
double maxSolarPanelAmperage = 5;

///Adjustment percentage per hour-of-day, so that we generate 0% at midnight. Makes the
  /// dummy data more realistic.
final _solarPanelGenerationPercentagePerHour = <double>[0, 0, 0, 0, 0, 0,
    0.1, 0.3, 0.6, 0.75, 0.8, 0.8,
    0.85, 0.95, 0.8, 0.75, 0.5, 0.3,
    0.1, 0, 0, 0, 0, 0];

@override
SystemInfo getSystemInfo() =>
SystemInfo()
  ..maxVoltage = 24
  ..ratedChargingCurrent = 40
    ..ratedDischargingCurrent = 40
    ..productType=ProductType.Controller
  ..productModel="RENOGY ROVER"
      ..softwareVersion="v1.2.3"
          ..hardwareVersion="v4.5.6"
  ..serialNumber="1501FFFF";

/// When the "device" was powered up (=when this class was created).
final _poweredOnAt = DateTime.now();
var _lastDailyStatsRetrievedAt = DateTime.now();
LocalDate? _lastDailyStatsRetrievedAtDay;
double _totalChargingBatteryAH;
double _cumulativePowerGenerationWH;
DailyStats? _lastDailyStats;
double _lastDailyStatsChargingAh;
double _lastDailyStatsPowerGenerationWh;

DailyStats _getDailyStats() => _lastDailyStats!;

HistoricalData _getHistoricalData() {
final daysUp = (DateTime.now().difference(_poweredOnAt)).inDays + 1;
return HistoricalData()
    ..daysUp = daysUp
    ..totalChargingBatteryAH = _totalChargingBatteryAH.toInt()
    ..cumulativePowerGenerationWH = _cumulativePowerGenerationWH.toInt();
}

override fun getAllData(cachedSystemInfo: SystemInfo?): RenogyData {
val systemInfo = cachedSystemInfo ?: getSystemInfo()
val now: LocalDateTime = LocalDateTime.now() // always local date since we calculate the generation percentage off it.

// generate dummy power data flowing from the solar panels; calculate the rest of the values
val solarPanelVoltage = Random.nextFloat(maxSolarPanelVoltage * 0.66f, maxSolarPanelVoltage)
var solarPanelCurrent = Random.nextFloat(maxSolarPanelAmperage / 2, maxSolarPanelAmperage)
// adjust the generated power according to the hour-of-day, so that we won't generate 100% power at midnight :-D
solarPanelCurrent *= solarPanelGenerationPercentagePerHour[now.time.hour]
// this is the most important value: this is the power (in Watts) the solar array is producing at this moment.
val solarPanelPowerW = solarPanelVoltage * solarPanelCurrent

val batteryVoltage = Random.nextFloat(
systemInfo.maxVoltage.toFloat(),
systemInfo.maxVoltage.toFloat() * 1.19f
)
// how much current flows into the battery at the moment.
val currentToBattery = solarPanelPowerW / batteryVoltage

val dummyPowerStatus = PowerStatus(
batterySOC = Random.nextUShort(66.toUShort(), 100.toUShort()),
batteryVoltage = batteryVoltage,
chargingCurrentToBattery = currentToBattery,
batteryTemp = Random.nextInt(18, 24),
controllerTemp = Random.nextInt(18, 24),
loadVoltage = 0f, // ignore the load, pretend there's none
loadCurrent = 0f,
loadPower = 0.toUShort(),
solarPanelVoltage = solarPanelVoltage,
solarPanelCurrent = solarPanelCurrent,
solarPanelPower = solarPanelPowerW.toInt().toUShort())

updateStats(solarPanelPowerW, batteryVoltage, now.date)

val dummyDailyStats = getDailyStats()
val dummyHistoricalData = getHistoricalData()
val dummyStatus = RenogyStatus(false, 0.toUByte(), ChargingState.MpptChargingMode, setOf())
val dummyRenogyData = RenogyData(
systemInfo,
dummyPowerStatus,
dummyDailyStats,
dummyHistoricalData,
dummyStatus)
return dummyRenogyData
}

override fun close() {}

/**
 * Updates statistics. Now we can calculate [DailyStats] and [HistoricalData] correctly.
 * @param solarPanelPowerW solar array produces this amount of watts now.
 * @param batteryVoltage actual battery voltage.
 */
private fun updateStats(solarPanelPowerW: Float, batteryVoltage: Float, today: LocalDate) {
val currentToBattery = solarPanelPowerW / batteryVoltage
val now = Instant.now()
val millisSinceLastMeasurement = now - lastDailyStatsRetrievedAt
val hoursSinceLastMeasurement = millisSinceLastMeasurement.inWholeMilliseconds / 1000f / 60f / 60f
val ampHoursToBatterySinceLastMeasurement: Float = currentToBattery * hoursSinceLastMeasurement
val energySinceLastMeasurementWh = solarPanelPowerW * hoursSinceLastMeasurement

totalChargingBatteryAH += ampHoursToBatterySinceLastMeasurement
cumulativePowerGenerationWH += ampHoursToBatterySinceLastMeasurement * batteryVoltage

if (lastDailyStats == null || today != lastDailyStatsRetrievedAtDay) {
lastDailyStatsRetrievedAtDay = today
lastDailyStats = DailyStats(batteryVoltage, batteryVoltage, currentToBattery, 0f,
solarPanelPowerW.toUInt().toUShort(), 0.toUShort(), ampHoursToBatterySinceLastMeasurement.toUInt().toUShort(),
0.toUShort(), energySinceLastMeasurementWh.toUInt().toUShort(), 0.toUShort())
lastDailyStatsChargingAh = ampHoursToBatterySinceLastMeasurement
lastDailyStatsPowerGenerationWh = energySinceLastMeasurementWh
} else {
lastDailyStatsChargingAh += ampHoursToBatterySinceLastMeasurement
lastDailyStatsPowerGenerationWh += energySinceLastMeasurementWh
lastDailyStats = DailyStats(
lastDailyStats!!.batteryMinVoltage.coerceAtMost(batteryVoltage),
lastDailyStats!!.batteryMaxVoltage.coerceAtLeast(batteryVoltage),
lastDailyStats!!.maxChargingCurrent.coerceAtLeast(currentToBattery),
0f,
lastDailyStats!!.maxChargingPower.coerceAtLeast(solarPanelPowerW.toUInt().toUShort()),
0.toUShort(),
lastDailyStatsChargingAh.toUInt().toUShort(),
0.toUShort(),
lastDailyStatsPowerGenerationWh.toUInt().toUShort(),
0.toUShort()
)
}

lastDailyStatsRetrievedAt = now
}

override fun toString(): String =
"DummyRenogyClient(maxSolarPanelVoltage=$maxSolarPanelVoltage, maxSolarPanelAmperage=$maxSolarPanelAmperage)"
}
