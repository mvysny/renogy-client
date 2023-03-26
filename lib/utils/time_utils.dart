import 'package:renogy_client/utils/utils.dart';

/// Represents a day.
class LocalDate with ComparableMixin<LocalDate> implements Comparable<LocalDate> {
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
  factory LocalDate.today() => LocalDate.from(DateTime.now());

  @override
  String toString() => "${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";

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

/// A time in day, in second resolution.
class LocalTime with ComparableMixin<LocalTime> implements Comparable<LocalTime> {
  /// hour, 0..23
  final int hour;
  /// minute, 0..59
  final int minute;
  /// second, 0..61
  final int second;

  LocalTime(this.hour, this.minute, this.second) {
    if (hour < 0 || hour > 23) throw ArgumentError.value(hour, "hour", "must be 0..23");
    if (minute < 0 || minute > 59) throw ArgumentError.value(minute, "minute", "must be 0..59");
    if (second < 0 || second > 61) throw ArgumentError.value(second, "second", "must be 0..61");
  }

  factory LocalTime.from(DateTime dateTime) {
    final local = dateTime.toLocal();
    return LocalTime(local.hour, local.minute, local.second);
  }
  factory LocalTime.now() => LocalTime.from(DateTime.now());

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalTime &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute &&
          second == other.second;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode ^ second.hashCode;

  @override
  int compareTo(LocalTime other) {
    var result = hour.compareTo(other.hour);
    if (result == 0) result = minute.compareTo(other.minute);
    if (result == 0) result = second.compareTo(other.second);
    return result;
  }

  static final midnight = LocalTime(0, 0, 0);
}

extension DateTimeExtensions on DateTime {
  /// Returns the date part.
  LocalDate getLocalDate() => LocalDate.from(this);
}
