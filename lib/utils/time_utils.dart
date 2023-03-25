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