String formatWhen(DateTime value) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute';
}

String formatCoords(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

String normalizeBase(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return text;
  if (!text.startsWith('http://') && !text.startsWith('https://')) {
    text = 'http://$text';
  }
  while (text.endsWith('/')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}
