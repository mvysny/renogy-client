import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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
  /// month, 1..12
  final int month;
  /// day, 1..31
  final int day;

  LocalDate(this.year, this.month, this.day) {
    if (month < 1 || month > 12) throw ArgumentError.value(month, "month", "must be 1..12");
    if (day < 1 || day > 31) throw ArgumentError.value(day, "day", "must be 1..31");
  }
  factory LocalDate.from(DateTime dateTime) {
    final local = dateTime.toLocal();
    return LocalDate(local.year, local.month, local.day);
  }
  factory LocalDate.now() => LocalDate.from(DateTime.now());

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
  LocalDate getLocalDate() => LocalDate.from(this);
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

int crc16ISOHDLC(Uint8List bytes) {
  int crc = 0xffff;
  for (var b in bytes) {
    crc ^= b;
    for (int i = 0; i < 8; i++)
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0x8408 : crc >> 1;
  }
  return crc ^ 0xffff;
}

int crc16_CCITT_FALSE(Uint8List bytes) {
  int initial = 0xFFFF; // initial value
  int polynomial = 0x1021;   // 0001 0000 0010 0001  (0, 5, 12)

  for (var b in bytes) {
    for (int i = 0; i < 8; i++) {
      bool bit = ((b >> (7-i) & 1) == 1);
      bool c15 = ((initial >> 15 & 1) == 1);
      initial <<= 1;
      if (c15 ^ bit) initial ^= polynomial;
    }
  }

  return initial &= 0xffff;
}
