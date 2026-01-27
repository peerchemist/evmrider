String? normalizeHexAddress(String value) {
  final normalized = value.trim();
  final isPrefixed = normalized.startsWith('0x') || normalized.startsWith('0X');
  final hex = isPrefixed ? normalized.substring(2) : normalized;
  if (hex.length != 40) return null;
  if (!RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(hex)) return null;
  if (!RegExp(r'[a-fA-F]').hasMatch(hex)) return null;
  return '0x${hex.toLowerCase()}';
}
