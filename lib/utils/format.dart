String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes < 1024) return '$bytes B';
  final units = <String>['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}

String formatSpeed(double bytesPerSecond) {
  if (bytesPerSecond <= 0) return '—';
  return '${formatBytes(bytesPerSecond.round())}/ث';
}

String? formatDuration(Duration? duration) {
  if (duration == null) return null;
  if (duration.inHours > 0) {
    return '${duration.inHours}س ${duration.inMinutes.remainder(60)}د';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}د ${duration.inSeconds.remainder(60)}ث';
  }
  return '${duration.inSeconds}ث';
}
