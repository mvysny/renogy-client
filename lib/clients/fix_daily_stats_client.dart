import 'dart:math';

import 'package:cron/cron.dart';
import 'package:logging/logging.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/utils/utils.dart';

/// Renogy resets the daily stats not at midnight, but at some arbitrary time during the day.
/// Currently, for me, the stats are reset at 9:17am, which is a huge wtf.
///
/// Therefore, we can not trust the daily data at all times. We'll detect the time period when the
/// Renogy daily stats can not be trusted, and we'll calculate them ourselves.
class FixDailyStatsClient implements RenogyClient {
  _DailyStatsStrategy _dailyStatsCalculator = _RenogyPassThrough(0);

  /// [DailyStats.powerGenerationWh] from Renogy's previous measurement. If the current measurement is lower,
  /// Renogy has performed the daily value reset.
  int? _prevPowerGenerationWh = null;
  /// Poll data from this client.
  final RenogyClient delegate;
  /// Set to true at midnight via cron.
  bool _crossedMidnight = false;
  /// Handle to cron task, canceled in [close].
  late ScheduledTask _cronTask;

  FixDailyStatsClient(this.delegate, Cron cron) {
    _log.info("Starting with daily stats $_dailyStatsCalculator");
    _cronTask = cron.schedule(scheduleMidnight, () { _crossedMidnight = true; });
  }

  static final _log = Logger((FixDailyStatsClient).toString());

  @override
  void close() {
    _cronTask.cancel();
    delegate.close();
  }

  @override
  RenogyData getAllData({SystemInfo? cachedSystemInfo}) {
    final RenogyData allData = delegate.getAllData(cachedSystemInfo: cachedSystemInfo);
    final DailyStats currentDailyStatsFromRenogy = allData.dailyStats;

    // if we crossed the day barrier, force DontTrustRenogyPeriod until Renogy zeroes the daily stats out itself.
    final crossedMidnight = _crossedMidnight;
    if (crossedMidnight) {
      _crossedMidnight = false;
      _dailyStatsCalculator = _DontTrustRenogyPeriod(allData);
      _log.info("Midnight: activating $_dailyStatsCalculator");
    }

    // detect whether Renogy finally performed the daily value reset.
    final prevPowerGenerationWh = _prevPowerGenerationWh;
    if (prevPowerGenerationWh != null && prevPowerGenerationWh > currentDailyStatsFromRenogy.powerGenerationWh) {
      // Yes: Renogy finally performed the daily value reset. Switch back to RenogyPassThrough
      if (_dailyStatsCalculator is _DontTrustRenogyPeriod) {
        final powerGenerationAtMidnight =
            (_dailyStatsCalculator as _DontTrustRenogyPeriod).powerGenerationAtMidnight;
        var powerGenerationDuringDontTrustPeriod = max(prevPowerGenerationWh - powerGenerationAtMidnight, 0);
        if (crossedMidnight) {
          // it's midnight AND renogy reset its stats => no "Don't Trust Renogy" period => zero
          powerGenerationDuringDontTrustPeriod = 0;
        }
        _dailyStatsCalculator = _RenogyPassThrough(powerGenerationDuringDontTrustPeriod);
        _log.info("Renogy performed the daily value reset, ending the 'Don't Trust Renogy' Period (powerGeneration: prev=$prevPowerGenerationWh,now=${currentDailyStatsFromRenogy.powerGenerationWh}); current daily stats=$_dailyStatsCalculator");
      } else {
        // not in "Don't Trust Renogy" period? corner-case - perhaps the client was just launched and hasn't hit midnight yet.
        _log.info("Renogy performed the daily value reset but there was no 'Don't Trust Renogy' Period, passing the daily stats through");
        _dailyStatsCalculator = _RenogyPassThrough(0);
      }
    }
    _prevPowerGenerationWh = currentDailyStatsFromRenogy.powerGenerationWh;

    _dailyStatsCalculator.process(allData);
    return allData;
  }

  @override
  SystemInfo getSystemInfo() {
    return delegate.getSystemInfo();
  }

  @override
  String toString() => "FixDailyStatsClient{$delegate}";
}

abstract class _DailyStatsStrategy {
  void process(RenogyData data);
}

class _RenogyPassThrough implements _DailyStatsStrategy {
  /// Cumulative power generation during the [DontTrustRenogyPeriod] period. We'll add this value to [DailyStats.powerGenerationWh]
  /// when outside of the "Don't Trust Renogy" period, to offset for power generation during the [DontTrustRenogyPeriod].
  final int powerGenerationDuringDontTrustPeriod;

  _RenogyPassThrough(this.powerGenerationDuringDontTrustPeriod);

  @override
  void process(RenogyData data) {
    data.dailyStats.powerGenerationWh += powerGenerationDuringDontTrustPeriod;
  }

  @override
  String toString() =>
      "RenogyPassThrough(powerGenerationDuringDontTrustPeriod=$powerGenerationDuringDontTrustPeriod)";
}

/// The time from midnight until 9:17am (or any other arbitrary point in time until Renogy finally resets the data)
/// is called the "Don't Trust Renogy" period. In this period, we don't trust Renogy - instead, we calculate the daily stats ourselves.
class _DontTrustRenogyPeriod implements _DailyStatsStrategy {
  final RenogyData midnightData;

  /// Cumulative power generation at midnight as reported by Renogy. We use this to offset the power generation
  /// during the "Don't Trust Renogy" period.
  final int powerGenerationAtMidnight;

  /// Statistics calculated by us.
  final _MyDailyStats myDailyStats;

  _DontTrustRenogyPeriod(this.midnightData)
      : powerGenerationAtMidnight = midnightData.dailyStats.powerGenerationWh,
        myDailyStats = _MyDailyStats(midnightData.powerStatus);

  @override
  void process(RenogyData data) {
    myDailyStats.update(data.powerStatus);
    myDailyStats.applyTo(data.dailyStats);
    data.dailyStats
      ..chargingAh = 0
      ..powerGenerationWh -= powerGenerationAtMidnight;
  }

  @override
  String toString() =>
      "DontTrustRenogyPeriod(powerGenerationAtMidnight=$powerGenerationAtMidnight)";
}

class _MyDailyStats {
  double batteryMinVoltage;
  double batteryMaxVoltage;
  double maxChargingCurrent;
  int maxChargingPower;

  _MyDailyStats(PowerStatus initialData)
      : batteryMinVoltage = initialData.batteryVoltage,
        batteryMaxVoltage = initialData.batteryVoltage,
        maxChargingCurrent = initialData.chargingCurrentToBattery,
        maxChargingPower = initialData.solarPanelPower;

  void update(PowerStatus powerStatus) {
    batteryMinVoltage = min(batteryMinVoltage, powerStatus.batteryVoltage);
    batteryMaxVoltage = max(batteryMaxVoltage, powerStatus.batteryVoltage);
    maxChargingCurrent =
        max(maxChargingCurrent, powerStatus.chargingCurrentToBattery);
    maxChargingPower = max(maxChargingPower, powerStatus.solarPanelPower);
  }

  void applyTo(DailyStats dailyStats) {
    dailyStats
      ..batteryMinVoltage = batteryMinVoltage
      ..batteryMaxVoltage = batteryMaxVoltage
      ..maxChargingCurrent = maxChargingCurrent
      ..maxChargingPower = maxChargingPower;
  }
}
