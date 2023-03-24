import 'dart:io';

import 'package:args/args.dart';
import 'package:renogy_client/utils.dart';

class Args {
  /// The file name of the serial device to communicate with, e.g. `/dev/ttyUSB0` . Pass in `dummy` for a dummy Renogy client
  final File device;

  /// if true, print the Renogy Rover status as JSON to stdout and quit.
  final bool printStatusOnly;

  /// CSV: dump date in UTC instead of local, handy for Grafana.
  final bool utc;

  /// If not null, appends status to this CSV file. Disables stdout status logging.
  final File? csv;

  /// If not null, appends status to a sqlite database. Disables stdout status logging.
  final File? sqlite;

  /// If not null, appends status to a postgresql database, disables stdout status logging. Accepts the connection url, e.g. `postgresql://user:pass@localhost:5432/postgres`
  final String? postgres;

  /// overwrites status to file other than the default 'status.json'
  final File? statusFile;

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
      this.sqlite,
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
    ..addOption('sqlite', help: 'appends status to a sqlite database, disables stdout status logging')
    ..addOption('postgres', help: 'appends status to a postgresql database, disables stdout status logging. Accepts the connection url, e.g. postgresql://user:pass@localhost:5432/postgres')
    ..addOption('statusfile', help: 'overwrites status to given file', defaultsTo: 'status.json')
    ..addOption('pollinterval', abbr: 'i', help: 'in seconds: how frequently to poll the controller for data', defaultsTo: '10')
    ..addOption('prunelog', help: 'prunes log entries older than x days', defaultsTo: '365')
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
      ArgResults a = _argParser.parse(args);
      if (a.rest.length != 1) throw ArgParserException("Please supply one serial device");
      var pollInterval = int.tryParse(a['pollinterval']);
      if (pollInterval == null) throw ArgParserException("pollinterval: not a number");
      var pruneLog = int.tryParse(a['prunelog']);
      if (pruneLog == null) throw ArgParserException("prunelog: not a number");
      return Args(
          File(a.rest.first),
          a['status'] as bool,
          a['utc'] as bool,
          _toFile(a['csv']),
          _toFile(a['sqlite']),
          a['postgres'],
          _toFile(a['statusfile']),
          pollInterval,
          pruneLog,
          a['verbose'] as bool
      );
    } catch (e) {
      print(e);
      _help();
    }
  }

  static File? _toFile(String? path) {
    if (path == null) {
      return null;
    } else {
      return File(path);
    }
  }

  @override
  String toString() {
    return 'Args{device: $device, printStatusOnly: $printStatusOnly, utc: $utc, csv: $csv, sqlite: $sqlite, postgres: $postgres, stateFile: $statusFile, pollInterval: $pollInterval, pruneLog: $pruneLog, verbose: $verbose}';
  }
}
