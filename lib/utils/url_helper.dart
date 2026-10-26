String getOptimizedUrl(String cloudinaryUrl, {int width = 480}) {
  final url = cloudinaryUrl.trim();
  if (url.isEmpty) return cloudinaryUrl;
  if (!url.contains('/upload/')) return cloudinaryUrl;
  if (url.contains(RegExp(r'/upload/[^/]*\bw_\d+'))) return cloudinaryUrl;

  return url.replaceFirst(
    '/upload/',
    '/upload/w_$width,q_auto,f_auto/',
  );
}
