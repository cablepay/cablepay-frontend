DateTime? safeParseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;

  final s = v.toString().trim();
  if (s.isEmpty) return null;

  return DateTime.tryParse(s);
}
