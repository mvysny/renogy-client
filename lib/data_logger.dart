import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/utils/closeable.dart';

/// Logs [RenogyData] somewhere.
abstract class DataLogger extends Closeable {
  /// Initializes the logger; e.g. makes sure the CSV file exists and creates one with a header if it doesn't.
  void init();

  /// Appends [data] to the logger.
  void append(RenogyData data);

  /// Deletes all records older than given number of [days].
  void deleteRecordsOlderThan(int days);
}

class CompositeDataLogger implements DataLogger {
  final dataLoggers = <DataLogger>[];

  @override
  void append(RenogyData data) {
    for (var dataLogger in dataLoggers) {
      dataLogger.append(data);
    }
  }

  @override
  void close() {
    for (var it in dataLoggers) {
      it.closeQuietly();
    }
    _log.fine("Closed $dataLoggers");
    dataLoggers.clear();
  }

  @override
  void deleteRecordsOlderThan(int days) {
    _log.info("Deleting old records");
    for (var dataLogger in dataLoggers) {
      dataLogger.deleteRecordsOlderThan(days);
    }
    _log.info("Successfully deleted old records");
  }

  @override
  void init() {
    for (var dataLogger in dataLoggers) {
      dataLogger.init();
    }
  }
  static final _log = Logger((CompositeDataLogger).toString());

  @override
  String toString() => dataLoggers.toString();
}

/// Logs [RenogyData] to stdout as a CSV stream.
class StdoutDataLogger implements DataLogger {
  final _csv = _CsvRenogyWriter(_CSVWriter(stdout));
  final bool utc;
  StdoutDataLogger(this.utc);

  @override
  void init() {
    _csv.writeHeader();
  }

  @override
  void deleteRecordsOlderThan(int days) {}

  @override
  void close() {}

  @override
  void append(RenogyData data) {
    _csv.writeLine(data, utc);
  }

  @override
  String toString() => (StdoutDataLogger).toString();
}

/// Prints CSV to given [StringSink].
class _CSVWriter {
  final StringSink _sink;
  _CSVWriter(this._sink);

  void writeHeader(List<String> header) {
    writeLine(header);
  }
  void writeLine(List<Object?> line) {
    _sink.writeln(const ListToCsvConverter().convert([line]));
  }
}

class _CsvRenogyWriter {
  final _formatter = DateFormat("yyyy-MM-dd'T'HH':'mm':'ss");
  final _CSVWriter _csv;

  _CsvRenogyWriter(this._csv);

  void writeHeader() {
    _csv.writeHeader([
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

  void writeLine(RenogyData data, bool utc) {
    final now = utc ? DateTime.now().toUtc() : DateTime.now();
    _csv.writeLine([
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
  final File file;
  final bool utc;
  /// Opened [file]. Created in [init].
  late IOSink _ioSink;
  late _CsvRenogyWriter _csv;
  CSVDataLogger(this.file, this.utc);

  @override
  void init() {
    if (file.existsSync()) {
      _ioSink = file.openWrite(mode: FileMode.writeOnlyAppend);
      _csv = _CsvRenogyWriter(_CSVWriter(_ioSink));
    } else {
      _ioSink = file.openWrite();
      _csv = _CsvRenogyWriter(_CSVWriter(_ioSink));
      _csv.writeHeader();
    }
  }

  @override
  void deleteRecordsOlderThan(int days) {}

  @override
  void close() async {
    try {
      await _ioSink.flush();
    } finally {
      await _ioSink.close();
    }
  }

  @override
  void append(RenogyData data) async {
    _csv.writeLine(data, utc);
    await _ioSink.flush();
  }

  @override
  String toString() => "CSVDataLogger{$file, utc=$utc}";
}
