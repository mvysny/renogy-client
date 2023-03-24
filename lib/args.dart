import 'dart:io';

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
  final File? stateFile;

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
      this.stateFile,
      this.pollInterval,
      this.pruneLog,
      this.verbose) {
    if (pollInterval <= 0)
      throw ArgumentError.value(
          pollInterval, "pollInterval", "Must be 1 or greater");
    if (pruneLog <= 0)
      throw ArgumentError.value(pruneLog, "pruneLog", "Must be 1 or greater");
  }

  /// If 'true' we'll feed the data from a dummy device. Useful for testing.
  bool get isDummy => device.name == 'dummy';

  static Args parse(List<String> args) {}

  @override
  String toString() {
    return 'Args{device: $device, printStatusOnly: $printStatusOnly, utc: $utc, csv: $csv, sqlite: $sqlite, postgres: $postgres, stateFile: $stateFile, pollInterval: $pollInterval, pruneLog: $pruneLog, verbose: $verbose}';
  }
}
