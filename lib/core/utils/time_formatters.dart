/// 将秒数格式化为适合工时展示的“时:分:秒”。
String formatDuration(int totalSeconds) {
  final int safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final int hours = safeSeconds ~/ 3600;
  final int minutes = (safeSeconds % 3600) ~/ 60;
  final int seconds = safeSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// 将可选时间格式化为本地日期时间文本。
String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '';
  }
  final String month = dateTime.month.toString().padLeft(2, '0');
  final String day = dateTime.day.toString().padLeft(2, '0');
  final String hour = dateTime.hour.toString().padLeft(2, '0');
  final String minute = dateTime.minute.toString().padLeft(2, '0');
  final String second = dateTime.second.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day $hour:$minute:$second';
}

/// 将时间格式化为本地日期文本。
String formatDate(DateTime dateTime) {
  final String month = dateTime.month.toString().padLeft(2, '0');
  final String day = dateTime.day.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day';
}
