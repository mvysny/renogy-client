import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
  /// calls [flush] before [close]
  Future flushAndClose() async {
    try {
      await flush();
    } finally {
      await closeQuietly();
    }
  }

  Future closeQuietly() async {
    try {
      await close();
    } on Exception catch (e, s) {
      Logger(runtimeType.toString()).warning("Failed to close $this", e, s);
    }
  }
}

mixin ComparableMixin<T> {
  int compareTo(T other);
  bool operator >(T other) => compareTo(other) > 0;
  bool operator >=(T other) => compareTo(other) >= 0;
  bool operator <(T other) => compareTo(other) < 0;
  bool operator <=(T other) => compareTo(other) <= 0;
}

/// Blocks until Enter is pressed.
Future waitForEnter() async {
  return stdin.transform(utf8.decoder).transform(LineSplitter()).first;
}
