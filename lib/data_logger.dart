import 'dart:io';

import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:influxdb_client/api.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/utils/closeable.dart';
import 'package:renogy_client/utils/utils.dart';

/// Logs [RenogyData] somewhere.
abstract class DataLogger extends AsyncCloseable {
  /// Initializes the logger; e.g. makes sure the CSV file exists and creates one with a header if it doesn't.
  Future<void> init();

  /// Appends [data] to the logger.
  Future<void> append(RenogyData data);

  /// Deletes all records older than given number of [days].
  Future<void> deleteRecordsOlderThan(int days);
}

/// Aggregates multiple [DataLogger]s. Add them to [dataLoggers] before calling [init].
class CompositeDataLogger implements DataLogger {
  final dataLoggers = <DataLogger>[];

  @override
  Future<void> append(RenogyData data) async {
    await Future.wait(dataLoggers.map((e) => e.append(data)));
  }

  @override
  Future<void> close() async {
    await Future.wait(dataLoggers.map((e) => e.closeQuietly()));
    _log.fine("Closed $dataLoggers");
    dataLoggers.clear();
  }

  @override
  Future<void> deleteRecordsOlderThan(int days) async {
    _log.info("Deleting old records");
    await Future.wait(dataLoggers.map((e) => e.deleteRecordsOlderThan(days)));
    _log.info("Successfully deleted old records");
  }

  @override
  Future<void> init() async {
    await Future.wait(dataLoggers.map((e) => e.init()));
  }
  static final _log = Logger((CompositeDataLogger).toString());

  @override
  String toString() => dataLoggers.toString();
}

/// Logs [RenogyData] to stdout as a CSV stream.
class StdoutDataLogger implements DataLogger {
  final _CsvRenogyWriter _csv;
  StdoutDataLogger(bool utc) : _csv = _CsvRenogyWriter(stdout, utc);

  @override
  Future<void> init() async {
    _csv.writeHeader();
  }

  @override
  Future<void> deleteRecordsOlderThan(int days) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> append(RenogyData data) async {
    _csv.writeLine(data);
  }

  @override
  String toString() => (StdoutDataLogger).toString();
}

/// Prints CSV to given [StringSink].
class _CsvRenogyWriter {
  final _formatter = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
  final StringSink _sink;
  final bool utc;

  _CsvRenogyWriter(this._sink, this.utc);

  void _writeLine(List<Object?> line) {
    _sink.writeln(const ListToCsvConverter().convert([line]));
  }

  void writeHeader() {
    _writeLine([
      "DateTime",
      "BatterySOC",
      "BatteryVoltage",
      "ChargingCurrentToBattery",
      "BatteryTemp",
      "ControllerTemp",
      "SolarPanelVoltage",
      "SolarPanelCurrent",
      "SolarPanelPower",
      "Daily.BatteryMinVoltage",
      "Daily.BatteryMaxVoltage",
      "Daily.MaxChargingCurrent",
      "Daily.MaxChargingPower",
      "Daily.ChargingAmpHours",
      "Daily.PowerGeneration",
      "Stats.DaysUp",
      "Stats.BatteryOverDischargeCount",
      "Stats.BatteryFullChargeCount",
      "Stats.TotalChargingBatteryAH",
      "Stats.CumulativePowerGenerationWH",
      "ChargingState",
      "Faults"
    ]);
  }

  void writeLine(RenogyData data) {
    final now = utc ? DateTime.now().toUtc() : DateTime.now();
    _writeLine([
      _formatter.format(now),
      data.powerStatus.batterySOC,
      data.powerStatus.batteryVoltage,
      data.powerStatus.chargingCurrentToBattery,
      data.powerStatus.batteryTemp,
      data.powerStatus.controllerTemp,
      data.powerStatus.solarPanelVoltage,
      data.powerStatus.solarPanelCurrent,
      data.powerStatus.solarPanelPower,
      data.dailyStats.batteryMinVoltage,
      data.dailyStats.batteryMaxVoltage,
      data.dailyStats.maxChargingCurrent,
      data.dailyStats.maxChargingPower,
      data.dailyStats.chargingAh,
      data.dailyStats.powerGenerationWh,
      data.historicalData.daysUp,
      data.historicalData.batteryOverDischargeCount,
      data.historicalData.batteryFullChargeCount,
      data.historicalData.totalChargingBatteryAH,
      data.historicalData.cumulativePowerGenerationWH,
      data.status.chargingState?.name,
      data.status.faults.map((e) => e.name).join(",")
    ]);
  }
}

/// Logs [RenogyData] to a CSV [file].
class CSVDataLogger implements DataLogger {
  /// The CSV file to log to.
  final File file;
  /// True if the time is logged in utc, false if it's logged in local.
  final bool utc;
  /// Opened [file]. Created in [init].
  late IOSink _ioSink;
  /// Writes to [_ioSink].
  late _CsvRenogyWriter _csv;
  CSVDataLogger(this.file, this.utc);

  @override
  Future<void> init() async {
    if (file.existsSync()) {
      _ioSink = file.openWrite(mode: FileMode.writeOnlyAppend);
      _csv = _CsvRenogyWriter(_ioSink, utc);
    } else {
      _ioSink = file.openWrite();
      _csv = _CsvRenogyWriter(_ioSink, utc);
      _csv.writeHeader();
    }
  }

  @override
  Future<void> deleteRecordsOlderThan(int days) async {}

  @override
  Future<void> close() async {
    await _ioSink.flushAndClose();
  }

  @override
  Future<void> append(RenogyData data) async {
    _csv.writeLine(data);
  }

  @override
  String toString() => "CSVDataLogger{$file, utc=$utc}";
}

/// Logs [RenogyData] to a PostgreSQL database.
class PostgresDataLogger implements DataLogger {
  // The connection URL, e.g. `postgresql://user:pass@localhost:5432/postgres`.
  final Uri url;

  PostgresDataLogger(this.url);

  factory PostgresDataLogger.parse(String url) {
    final uri = Uri.parse(url);
    if (uri.scheme != 'postgresql') throw ArgumentError.value(url, "url", "Not a postgresql:// URL");
    return PostgresDataLogger(uri);
  }

  PostgreSQLConnection _newConnection() {
    var userInfo = url.userInfo.split(':');
    final String? username = userInfo.firstOrNull;
    final String? password = userInfo.length >= 2 ? userInfo[1] : null;
    return PostgreSQLConnection(url.host, url.port == 0 ? 5432 : url.port, url.pathSegments[0], username: username, password: password);
  }

  PostgreSQLConnection? _conn;

  @override
  Future<void> append(RenogyData data) async {
    String? faults = data.status.faults.map((e) => e.name).join(",");
    faults = faults.isEmpty ? null : faults;
    final params = <String, Object?>{
      "DateTime": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "BatterySOC": data.powerStatus.batterySOC,
      "BatteryVoltage": data.powerStatus.batteryVoltage,
      "ChargingCurrentToBattery": data.powerStatus.chargingCurrentToBattery,
      "BatteryTemp": data.powerStatus.batteryTemp,
      "ControllerTemp": data.powerStatus.controllerTemp,
      "SolarPanelVoltage": data.powerStatus.solarPanelVoltage,
      "SolarPanelCurrent": data.powerStatus.solarPanelCurrent,
      "SolarPanelPower": data.powerStatus.solarPanelPower,
      "Daily_BatteryMinVoltage": data.dailyStats.batteryMinVoltage,
      "Daily_BatteryMaxVoltage": data.dailyStats.batteryMaxVoltage,
      "Daily_MaxChargingCurrent": data.dailyStats.maxChargingCurrent,
      "Daily_MaxChargingPower": data.dailyStats.maxChargingPower,
      "Daily_ChargingAmpHours": data.dailyStats.chargingAh,
      "Daily_PowerGeneration": data.dailyStats.powerGenerationWh,
      "Stats_DaysUp": data.historicalData.daysUp,
      "Stats_BatteryOverDischargeCount":
          data.historicalData.batteryOverDischargeCount,
      "Stats_BatteryFullChargeCount":
          data.historicalData.batteryFullChargeCount,
      "Stats_TotalChargingBatteryAH":
          data.historicalData.totalChargingBatteryAH,
      "Stats_CumulativePowerGenerationWH":
          data.historicalData.cumulativePowerGenerationWH,
      "ChargingState": data.status.chargingState?.value,
      "Faults": faults
    };

    await _conn!.execute("insert into log (${params.keys.join(",")}) values (${params.keys.map((e) => "@$e").join(",")})",
      substitutionValues: params);
  }

  @override
  Future<void> close() async {
    await _conn?.close();
    _conn = null;
    _log.fine("PostgreSQL connection closed");
  }

  @override
  Future<void> deleteRecordsOlderThan(int days) async {
    final int deleteOlderThan = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - Duration(days: days).inSeconds;
    await _conn!.execute("delete from log where DateTime <= $deleteOlderThan");
  }

  @override
  Future<void> init() async {
    _conn = _newConnection();
    await _conn!.open();
    await _conn!.execute("CREATE TABLE IF NOT EXISTS log (" +
        "DateTime bigint primary key not null," +
        "BatterySOC smallint not null," +
        "BatteryVoltage real not null," +
        "ChargingCurrentToBattery real not null," +
        "BatteryTemp smallint not null," +
        "ControllerTemp smallint not null," +
        "SolarPanelVoltage real not null," +
        "SolarPanelCurrent real not null," +
        "SolarPanelPower smallint not null," +
        "Daily_BatteryMinVoltage real not null," +
        "Daily_BatteryMaxVoltage real not null," +
        "Daily_MaxChargingCurrent real not null," +
        "Daily_MaxChargingPower smallint not null," +
        "Daily_ChargingAmpHours smallint not null," +
        "Daily_PowerGeneration smallint not null," +
        "Stats_DaysUp int not null," +
        "Stats_BatteryOverDischargeCount smallint not null," +
        "Stats_BatteryFullChargeCount smallint not null," +
        "Stats_TotalChargingBatteryAH int not null," +
        "Stats_CumulativePowerGenerationWH int not null," +
        "ChargingState smallint," +
        "Faults text)");
  }

  @override
  String toString() => 'PostgresDataLogger{url: $url}';

  static final _log = Logger((PostgresDataLogger).toString());
}

/// Writes to an InfluxDB 2.x database, to the `renogy` measurement.
class InfluxDbDataLogger implements DataLogger {
  // The connection URL, e.g. `http://localhost:8086?org=my_org&bucket=my_bucket&token=xyz`.
  final String url;
  final String org;
  final String bucket;
  final String token;
  InfluxDbDataLogger(this.url, this.org, this.bucket, this.token);

  late InfluxDBClient _client;
  late WriteService _writeService;
  late DeleteService _deleteService;

  @override
  Future<void> append(RenogyData data) async {
    String? faults = data.status.faults.map((e) => e.name).join(",");
    faults = faults.isEmpty ? null : faults;
    final point = Point('renogy')
        .addField("BatterySOC", data.powerStatus.batterySOC)
        .addField("BatteryVoltage", data.powerStatus.batteryVoltage)
        .addField("ChargingCurrentToBattery",
            data.powerStatus.chargingCurrentToBattery)
        .addField("BatteryTemp", data.powerStatus.batteryTemp)
        .addField("ControllerTemp", data.powerStatus.controllerTemp)
        .addField("SolarPanelVoltage", data.powerStatus.solarPanelVoltage)
        .addField("SolarPanelCurrent", data.powerStatus.solarPanelCurrent)
        .addField("SolarPanelPower", data.powerStatus.solarPanelPower)
        .addField("Daily_BatteryMinVoltage", data.dailyStats.batteryMinVoltage)
        .addField("Daily_BatteryMaxVoltage", data.dailyStats.batteryMaxVoltage)
        .addField(
            "Daily_MaxChargingCurrent", data.dailyStats.maxChargingCurrent)
        .addField("Daily_MaxChargingPower", data.dailyStats.maxChargingPower)
        .addField("Daily_ChargingAmpHours", data.dailyStats.chargingAh)
        .addField("Daily_PowerGeneration", data.dailyStats.powerGenerationWh)
        .addField("Stats_DaysUp", data.historicalData.daysUp)
        .addField("Stats_BatteryOverDischargeCount",
            data.historicalData.batteryOverDischargeCount)
        .addField("Stats_BatteryFullChargeCount",
            data.historicalData.batteryFullChargeCount)
        .addField("Stats_TotalChargingBatteryAH",
            data.historicalData.totalChargingBatteryAH)
        .addField("Stats_CumulativePowerGenerationWH",
            data.historicalData.cumulativePowerGenerationWH)
        .addField("ChargingState", data.status.chargingState?.value)
        .addField("Faults", faults)
        .time(DateTime.now().toUtc());
    await _writeService.write(point);
  }

  @override
  Future<void> close() async {
    _client.close();
  }

  @override
  Future<void> deleteRecordsOlderThan(int days) async {
    await _deleteService.delete(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        stop: DateTime.now().toUtc().subtract(Duration(days: days)),
        org: org,
        bucket: bucket);
  }

  @override
  Future<void> init() async {
    _client = InfluxDBClient(url: url,
        token: token,
        org: org,
        bucket: bucket);
    await _client.getPingApi().getPingWithHttpInfo();
    _writeService = _client.getWriteService();
    _deleteService = _client.getDeleteService();
  }

  // Accepts the connection URL, e.g. `http://localhost:8086?org=my_org&bucket=my_bucket&token=xyz`.
  static InfluxDbDataLogger parse(String url) {
    final uri = Uri.parse(url);
    final link = url.split("?").first;
    final token = ArgumentError.checkNotNull(uri.queryParameters["token"], 'token');
    final org = ArgumentError.checkNotNull(uri.queryParameters["org"], 'org');
    final bucket = ArgumentError.checkNotNull(uri.queryParameters["bucket"], 'bucket');
    return InfluxDbDataLogger(link, org, bucket, token);
  }

  @override
  String toString() => 'InfluxDbDataLogger{url: $url, org: $org, bucket: $bucket, token: $token}';
}
