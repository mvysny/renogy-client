/// Represents a day.
class LocalDate implements Comparable<LocalDate> {
  final int year;
  /// month, 1..12
  final int month;
  /// day, 1..31
  final int day;

  LocalDate(this.year, this.month, this.day) {
    RangeError.checkValueInInterval(month, 1, 12, "month");
    RangeError.checkValueInInterval(day, 1, 31, "day");
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
  bool operator >(LocalDate other) => compareTo(other) > 0;
  bool operator >=(LocalDate other) => compareTo(other) >= 0;
  bool operator <(LocalDate other) => compareTo(other) < 0;
  bool operator <=(LocalDate other) => compareTo(other) <= 0;
}

extension DateTimeExtensions on DateTime {
  /// Returns the date part.
  LocalDate getLocalDate() => LocalDate.from(this);
}
