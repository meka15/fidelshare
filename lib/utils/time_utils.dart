class EthiopianTimeUtils {
  /// Converts a standard DateTime to Ethiopian Clock string (e.g., 5:38)
  static String format(DateTime dateTime) {
    return _calculate(dateTime.hour, dateTime.minute);
  }

  /// Converts a "HH:mm" standard string to Ethiopian Clock string
  static String formatString(String timeStr) {
    return _calculateString(timeStr, includePeriod: true);
  }

  /// Just the numbers for editing (e.g., 2:00)
  static String formatRaw(String timeStr) {
    return _calculateString(timeStr, includePeriod: false);
  }

  static String _calculateString(String timeStr, {required bool includePeriod}) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return _calculate(hour, minute, includePeriod: includePeriod);
    } catch (e) {
      return timeStr;
    }
  }

  /// Converts Ethiopian Local Time input to Standard 24h
  /// [etHour] 1-12
  /// [isNight] true if it's the Night cycle (after sunset)
  static String localToStandard(int etHour, int minute, bool isNight) {
    // Ethiopian Sunrise (12:00) is 06:00 Standard
    // Ethiopian Sunset (12:00) is 18:00 Standard
    
    int baseHour = isNight ? 18 : 6;
    int hourOffset = (etHour == 12) ? 0 : etHour;
    int standardHour = (baseHour + hourOffset) % 24;

    return "${standardHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
  }

  static String _calculate(int hour, int minute, {bool includePeriod = true}) {
    // Offset by 6 hours
    int etHour = (hour - 6) % 12;
    if (etHour <= 0) etHour += 12;

    String minuteStr = minute.toString().padLeft(2, '0');
    
    if (!includePeriod) return "$etHour:$minuteStr";

    // Determine Period (Day vs Night cycle)
    // 6 AM to 6 PM is "Day" in Ethiopia
    String period = (hour >= 6 && hour < 18) ? "Day" : "Night";
    
    return "$etHour:$minuteStr $period";
  }
}
