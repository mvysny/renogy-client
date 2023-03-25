import 'package:logging/logging.dart';
import 'package:renogy_client/clients/renogy_client.dart';

/// Logs [RenogyData] somewhere.
abstract class DataLogger {
  /// Initializes the logger; e.g. makes sure the CSV file exists and creates one with a header if it doesn't.
  void init();

  /// Appends [data] to the logger.
  void append(RenogyData data);

  /// Deletes all records older than given number of [days].
  void deleteRecordsOlderThan(int days);

  /// closes the logger.
  void close();
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
    for (var dataLogger in dataLoggers) {
      try {
        dataLogger.close();
      } on Exception catch (e, s) {
        _log.warning('Failed to close $dataLogger: $e\n$s');
      }
    }
  }

  @override
  void deleteRecordsOlderThan(int days) {
    for (var dataLogger in dataLoggers) {
      dataLogger.deleteRecordsOlderThan(days);
    }
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

class StdoutDataLogger implements DataLogger {
  @override
  void init() {}

  @override
  void deleteRecordsOlderThan(int days) {}

  @override
  void close() {}

  @override
  void append(RenogyData data) {
    print(data);
  }
}
