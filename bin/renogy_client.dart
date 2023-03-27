import 'dart:async';

import 'package:cron/cron.dart';
import 'package:libserialport/libserialport.dart';
import 'package:logging/logging.dart';
import 'package:renogy_client/args.dart';
import 'package:renogy_client/clients/dummy_renogy_client.dart';
import 'package:renogy_client/clients/fix_daily_stats_client.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/clients/renogy_modbus_client.dart';
import 'package:renogy_client/utils/closeable.dart';
import 'package:renogy_client/utils/io.dart';
import 'package:renogy_client/utils/utils.dart';

void main(List<String> arguments) async {
  print('Available serial ports: ${SerialPort.availablePorts}');
  final args = Args.parse(arguments);

  final SerialPortIO? io = args.isDummy ? null : SerialPortIO(SerialPort(args.device.path));
  try {
    io?.configure();
    final cron = Cron();
    try {
      final RenogyClient client = io == null
          ? DummyRenogyClient()
          : FixDailyStatsClient(RenogyModbusClient(io), cron);
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
  } finally {
    io?.closeQuietly();
    _log.fine("Closed $io");
  }
}

final _log = Logger.root;

Future<void> _mainLoop(RenogyClient client, Args args, Cron cron) async {
  _log.info("Accessing solar controller via $client");
  final systemInfo = client.getSystemInfo();
  _log.info("Solar Controller: $systemInfo");
  final dataLogger = args.newDataLogger();
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
