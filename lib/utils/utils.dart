import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cron/cron.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

extension FileExtention on FileSystemEntity {
  /// Returns the file/directory name, excluding path, but including the extension (if any).
  String get name {
    return basename(path);
  }
}

extension RandomRanges on Random {
  /// Returns a random int value, in the range of min (including) .. max (excluding).
  int nextIntRange(int min, int max) {
    if (min > max) throw ArgumentError.value(max, "max", "must be higher than $min");
    return nextInt(max - min) + min;
  }
  /// Returns a random int value, in the range of min (including) .. max (excluding).
  double nextDoubleRange(double min, double max) {
    if (min > max) throw ArgumentError.value(max, "max", "must be higher than $min");
    return nextDouble() * (max - min) + min;
  }
}

final Random random = Random();

extension CloseAndFlush on IOSink {
  /// Calls [flush] before [close].
  Future<void> flushAndClose() async {
    try {
      await flush();
    } finally {
      await closeQuietly();
    }
  }

  /// Closes this resource asynchronously. Does not throw an exception.
  Future<void> closeQuietly() async {
    try {
      await close();
    } on Exception catch (e, s) {
      Logger(runtimeType.toString()).warning("Failed to close $this", e, s);
    }
  }
}

/// Blocks until Enter is pressed.
Future<String> waitForEnter() async {
  return await stdin.transform(utf8.decoder).transform(LineSplitter()).first;
}

/// Cron schedule representing midnight.
final scheduleMidnight = Schedule.parse("0 0 0 * * *");
