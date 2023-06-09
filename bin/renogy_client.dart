import 'dart:async';

import 'package:cron/cron.dart';
import 'package:logging/logging.dart';
import 'package:renogy_client/args.dart';
import 'package:renogy_client/clients/dummy_renogy_client.dart';
import 'package:renogy_client/clients/fix_daily_stats_client.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/clients/retry_on_timeout_client.dart';
import 'package:renogy_client/data_logger.dart';
import 'package:renogy_client/utils/closeable.dart';
import 'package:renogy_client/utils/utils.dart';

void main(List<String> arguments) async {
  final args = Args.parse(arguments);

  final cron = Cron();
  try {
    final RenogyClient client = args.isDummy
        ? DummyRenogyClient()
        : FixDailyStatsClient(RetryOnTimeoutClient(const Duration(seconds: 1), args.device), cron);
    try {
      if (args.printStatusOnly) {
        final RenogyData allData = client.getAllData();
        print(allData.toJsonString());
      } else {
        await _mainLoop(client, args, cron);
      }
    } finally {
      client.closeQuietly();
      _log.fine("Closed $client");
    }
  } finally {
    await cron.close();
    _log.fine("Closed internal cron");
  }
}

final _log = Logger.root;

Future<void> _mainLoop(RenogyClient client, Args args, Cron cron) async {
  _log.info("Accessing solar controller via $client");
  final systemInfo = client.getSystemInfo();
  _log.info("Solar Controller: $systemInfo");
  final DataLogger dataLogger = await args.newDataLogger();
  try {
    _log.info("Polling the solar controller every ${args.pollInterval} seconds; writing status to ${args.statusFile}, appending data to $dataLogger");
    _log.info("Press ENTER to end the program\n");

    await dataLogger.init();
    await dataLogger.deleteRecordsOlderThan(args.pruneLog);

    cron.schedule(scheduleMidnight, () async {
      try {
        await dataLogger.deleteRecordsOlderThan(args.pruneLog);
      } catch (e, t) {
        _log.severe("Failed to prune old records", e, t);
      }
    });
    looprun(Timer? t) async {
      try {
        _log.fine("Getting all data from $client");
        final RenogyData allData =
            client.getAllData(cachedSystemInfo: systemInfo);
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
    await dataLogger.closeQuietly();
  }
}
