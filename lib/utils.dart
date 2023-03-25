import 'dart:io';
import 'dart:math';
import 'package:path/path.dart';

extension FileExtention on FileSystemEntity {
  /// Returns the file/directory name, excluding path, but including the extension (if any).
  String get name {
    return basename(path);
  }
}

/// Represents a day.
class LocalDate implements Comparable<LocalDate> {
  final int year;
  final int month;
  final int day;

  LocalDate(this.year, this.month, this.day);

  @override
  String toString() => "$year-$month-$day";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => year.hashCode ^ month.hashCode ^ day.hashCode;

  @override
  int compareTo(LocalDate other) {
    var result = year.compareTo(other.year);
    if (result == 0) result = month.compareTo(other.month);
    if (result == 0) result = day.compareTo(other.day);
    return result;
  }
}

extension DateTimeExtensions on DateTime {
  /// Returns the date part.
  LocalDate getLocalDate() {
    var local = this.toLocal();
    return LocalDate(local.year, local.month, local.day);
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
