import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:renogy_client/args.dart';
import 'package:renogy_client/clients/dummy_renogy_client.dart';
import 'package:renogy_client/clients/renogy_client.dart';

void main(List<String> arguments) {
  final args = Args.parse(arguments);

  final RenogyClient client = DummyRenogyClient();
  if (args.printStatusOnly) {
    try {
      final RenogyData allData = client.getAllData();
      print(allData.toJsonString());
    } finally {
      client.close();
    }
  } else {
    try {
      _mainLoop(client, args);
    } on Exception {
      client.close();
      rethrow;
    }
  }
}

final _log = Logger.root;

void _mainLoop(RenogyClient client, Args args) {
  _log.info("Accessing solar controller via $client");
  final systemInfo = client.getSystemInfo();
  _log.info("Solar Controller: $systemInfo");
  final dataLogger = args.newDataLogger();
  try {
    _log.info("Polling the solar controller every ${args
        .pollInterval} seconds; writing status to ${args
        .statusFile}, appending data to $dataLogger");
    _log.info("Press CTRL+C or send SIGTERM to end the program\n");

    dataLogger.init();
    dataLogger.deleteRecordsOlderThan(args.pruneLog);

    // val midnightAlarm = MidnightAlarm { dataLogger.deleteRecordsOlderThan(args.pruneLog) }
    looprun(Timer? t) {
      try {
        _log.fine("Getting all data from $client");
        final RenogyData allData = client.getAllData(
            cachedSystemInfo: systemInfo);
        _log.fine("Writing data to ${args.statusFile}");
        args.statusFile.writeAsStringSync(allData.toJsonString());
        dataLogger.append(allData);
        // todo midnightAlarm.tick();
        _log.fine("Main loop: done");
      } on Exception catch (e, s) {
        // don't crash on exception; print it out and continue. The KeepOpenClient will recover for serialport errors.
        _log.warning("Main loop failure", e, s);
      }
    }
    looprun(null);

    final t = Timer.periodic(Duration(seconds: args.pollInterval), looprun);
    terminate(ProcessSignal signal) {
      _log.fine("Shutting down");
      t.cancel();
      dataLogger.close();
      client.close();
      _log.fine("Closed $client");
      exit(0);
    }

    ProcessSignal.sigint.watch().listen(terminate); // CTRL+C
    ProcessSignal.sigterm.watch().listen(terminate); // we're killed by someone
    // the function may now terminate (and main() along with it): the Timer+Event Queue
    // will keep the process alive. The terminate() function will be called on CTRL+C,
    // canceling the timer, closing everything and calling exit(0).
  } on Exception {
    dataLogger.close();
    rethrow;
  }
}
