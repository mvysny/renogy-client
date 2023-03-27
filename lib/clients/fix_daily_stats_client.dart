import 'package:logging/logging.dart';
import 'package:renogy_client/clients/renogy_client.dart';

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
  final RenogyClient delegate;

  FixDailyStatsClient(this.delegate) {
    _log.info("Starting with daily stats $_dailyStatsCalculator");
  }

  static final _log = Logger((FixDailyStatsClient).toString());

  @override
  void close() {
    delegate.close();
  }

  @override
  RenogyData getAllData({SystemInfo? cachedSystemInfo}) {
    // TODO: implement getAllData
    throw UnimplementedError();
  }

  @override
  SystemInfo getSystemInfo() {
    return delegate.getSystemInfo();
  }
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
