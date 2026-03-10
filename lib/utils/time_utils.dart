import 'package:intl/intl.dart';

class EthiopianTimeUtils {
  /// Converts a standard DateTime to Ethiopian Clock string (e.g., 5:38)
  static String format(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    return _calculate(hour, minute);
  }

  /// Converts a "HH:mm" string to Ethiopian Clock string
  static String formatString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return _calculate(hour, minute);
    } catch (e) {
      return timeStr; // Fallback to original if parsing fails
    }
  }

  static String _calculate(int hour, int minute) {
    // Ethiopian hour calculation
    // Standard 6:00 (6 AM) is 12:00 in ET
    // Standard 12:00 (12 PM) is 6:00 in ET
    int etHour = (hour + 18) % 12;
    if (etHour == 0) etHour = 12;

    String minuteStr = minute.toString().padLeft(2, '0');
    String period = _getPeriod(hour);
    
    return "$etHour:$minuteStr $period";
  }

  static String _getPeriod(int hour) {
    if (hour >= 6 && hour < 12) return "Morning";
    if (hour >= 12 && hour < 18) return "Day";
    if (hour >= 18 && hour < 24) return "Evening";
    return "Night";
  }
}
