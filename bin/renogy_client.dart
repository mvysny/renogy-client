import 'dart:async';

import 'package:cron/cron.dart';
import 'package:logging/logging.dart';
import 'package:renogy_client/args.dart';
import 'package:renogy_client/clients/dummy_renogy_client.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/utils/closeable.dart';
import 'package:renogy_client/utils/utils.dart';

void main(List<String> arguments) async {
  final args = Args.parse(arguments);

  final RenogyClient client = DummyRenogyClient();
  try {
    if (args.printStatusOnly) {
      final RenogyData allData = client.getAllData();
      print(allData.toJsonString());
    } else {
      await _mainLoop(client, args);
    }
  } finally {
    client.closeQuietly();
    _log.fine("Closed $client");
  }
}

final _log = Logger.root;

Future<void> _mainLoop(RenogyClient client, Args args) async {
  _log.info("Accessing solar controller via $client");
  final systemInfo = client.getSystemInfo();
  _log.info("Solar Controller: $systemInfo");
  final dataLogger = args.newDataLogger();
  try {
    _log.info("Polling the solar controller every ${args.pollInterval} seconds; writing status to ${args.statusFile}, appending data to $dataLogger");
    _log.info("Press ENTER to end the program\n");

    await dataLogger.init();
    await dataLogger.deleteRecordsOlderThan(args.pruneLog);

    final cron = Cron();
    try {
      cron.schedule(Schedule.parse("0 0 0 * * *"), () async {
        try {
          await dataLogger.deleteRecordsOlderThan(args.pruneLog);
        } catch (e, t) {
          _log.severe("Failed to prune old records", e, t);
        }
      });
      looprun(Timer? t) async {
        try {
          _log.fine("Getting all data from $client");
          final RenogyData allData = client.getAllData(cachedSystemInfo: systemInfo);
          _log.fine("Writing data to ${args.statusFile}");
          await args.statusFile.writeAsString(allData.toJsonString());
          await dataLogger.append(allData);
          _log.fine("Main loop: done");
        } on Exception catch (e, s) {
          // don't crash on exception; print it out and continue. The KeepOpenClient will recover for serialport errors.
          _log.warning("Main loop failure", e, s);
        }
      }
      looprun(null);
      final t = Timer.periodic(Duration(seconds: args.pollInterval), looprun);
      try {
        await waitForEnter();
      } finally {
        _log.fine("Shutting down");
        t.cancel();
      }
    } finally {
      await cron.close();
    }
  } finally {
    await dataLogger.closeQuietly();
  }
}
