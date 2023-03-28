import 'dart:io';

import 'package:args/args.dart';
import 'package:intl/intl.dart';
import 'package:libserialport/libserialport.dart';
import 'package:logging/logging.dart';
import 'package:renogy_client/data_logger.dart';
import 'package:renogy_client/utils/utils.dart';

class Args {
  /// The file name of the serial device to communicate with, e.g. `/dev/ttyUSB0` . Pass in `dummy` for a dummy Renogy client
  final File device;

  /// if true, print the Renogy Rover status as JSON to stdout and quit.
  final bool printStatusOnly;

  /// CSV: dump date in UTC instead of local, handy for Grafana.
  final bool utc;

  /// If not null, appends status to this CSV file. Disables stdout status logging.
  final File? csv;

  /// If not null, appends status to a postgresql database, disables stdout status logging. Accepts the connection url, e.g. `postgresql://user:pass@localhost:5432/postgres`
  final String? postgres;

  /// overwrites status to file other than the default 'status.json'
  final File statusFile;

  /// in seconds: how frequently to poll the controller for data, defaults to 10
  final int pollInterval;

  /// Prunes log entries older than x days, defaults to 365. Applies to databases only; a CSV file is never pruned.
  final int pruneLog;

  /// Print verbosely what I'm doing
  final bool verbose;

  Args(
      this.device,
      this.printStatusOnly,
      this.utc,
      this.csv,
      this.postgres,
      this.statusFile,
      this.pollInterval,
      this.pruneLog,
      this.verbose) {
    if (pollInterval <= 0) throw ArgumentError.value(pollInterval, "pollInterval", "Must be 1 or greater");
    if (pruneLog <= 0) throw ArgumentError.value(pruneLog, "pruneLog", "Must be 1 or greater");
  }

  /// If 'true' we'll feed the data from a dummy device. Useful for testing.
  bool get isDummy => device.name == 'dummy';

  static final _argParser = ArgParser()
    ..addFlag('status', help: 'print the Renogy Rover status as JSON to stdout and quit', negatable: false)
    ..addFlag('utc', help: 'CSV: dump date in UTC instead of local, handy for Grafana', negatable: false)
    ..addOption('csv', help: 'appends status to a CSV file, disables stdout status logging')
    ..addOption('postgres', help: 'appends status to a postgresql database, disables stdout status logging. Accepts the connection url, e.g. postgresql://user:pass@localhost:5432/postgres')
    ..addOption('statusfile', help: 'overwrites status to given file', defaultsTo: 'status.json')
    ..addOption('pollinterval', abbr: 'i', help: 'in seconds: how frequently to poll the controller for data', defaultsTo: '10')
    ..addOption('prunelog', help: 'prunes log entries older than x days', defaultsTo: '365')
    ..addFlag('list-serial-ports', help: 'lists all available serial ports and quits', negatable: false)
    ..addFlag('verbose', help: 'Print verbosely what I\'m doing', negatable: false);

  /// Prints help and stops the program.
  static Never _help() {
    print('Usage: renogy_client options_list');
    print('Arguments:');
    print('  device -> the file name of the serial device to communicate with, e.g. /dev/ttyUSB0 . Pass in `dummy` for a dummy Renogy client');
    print('Options:');
    print(_argParser.usage);
    exit(64); // Exit code 64 indicates a usage error.
  }

  /// Parses the command-line args.
  static Args parse(List<String> args) {
    try {
      final ArgResults ar = _argParser.parse(args);

      if (ar['list-serial-ports'] as bool) {
        print('Available serial ports: ${SerialPort.availablePorts}');
        exit(0);
      }
      if (ar.rest.length != 1) throw ArgParserException("Please supply one serial device");
      final pollInterval = int.tryParse(ar['pollinterval']);
      if (pollInterval == null) throw ArgParserException("pollinterval: not a number");
      if (pollInterval < 1) throw ArgParserException("pollinterval: must be 1 or higher");
      final pruneLog = int.tryParse(ar['prunelog']);
      if (pruneLog == null) throw ArgParserException("prunelog: not a number");
      if (pruneLog < 1) throw ArgParserException("pruneLog: must be 1 or higher");

      final Args a = Args(
          File(ar.rest.first),
          ar['status'] as bool,
          ar['utc'] as bool,
          _toFile(ar['csv']),
          ar['postgres'],
          _toFile(ar['statusfile'])!,
          pollInterval,
          pruneLog,
          ar['verbose'] as bool
      );

      _configureLogger(a.verbose);
      _log.fine(a);
      return a;
    } on ArgParserException catch(e, s) {
      print(e);
      print(s);
      _help();
    }
  }

  static void _configureLogger(bool verbose) {
    Logger.root.level = Level.INFO;
    final DateFormat timestampFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    Logger.root.onRecord.listen((record) {
      print('${timestampFormatter.format(record.time)} [${record.level.name}] ${record.loggerName}: ${record.message}');
      if (record.error != null) print(record.error);
      if (record.stackTrace != null) print(record.stackTrace);
    });
    if (verbose) Logger.root.level = Level.ALL;
  }

  static File? _toFile(String? path) => path == null ? null : File(path);

  static final Logger _log = Logger((Args).toString());

  @override
  String toString() {
    return 'Args{device: $device, printStatusOnly: $printStatusOnly, utc: $utc, csv: $csv, postgres: $postgres, stateFile: $statusFile, pollInterval: $pollInterval, pruneLog: $pruneLog, verbose: $verbose}';
  }

  /// Creates and returns the data logger. Don't forget to call [DataLogger.init].
  Future<DataLogger> newDataLogger() async {
    final result = CompositeDataLogger();
    try {
      if (csv != null) {
        result.dataLoggers.add(CSVDataLogger(csv!, utc));
      }
      if (postgres != null) {
        result.dataLoggers.add(PostgresDataLogger.parse(postgres!));
      }
      if (result.dataLoggers.isEmpty) {
        result.dataLoggers.add(StdoutDataLogger(utc));
      }
    } catch(e) {
      await result.close();
      rethrow;
    }
    return result;
  }
}
