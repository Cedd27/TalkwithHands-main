import '../services/api_config.dart';
import 'url_helper.dart';

String normalizePlayableVideoUrl(String value) {
  final url = value.trim();
  if (url.isEmpty) return '';

  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  if (!uri.hasScheme) return absoluteBackendUrl(url) ?? url;

  final host = uri.host.toLowerCase();
  if (!host.endsWith('drive.google.com') &&
      !host.endsWith('drive.usercontent.google.com')) {
    return getOptimizedUrl(url, width: 480);
  }

  final fileId = _googleDriveFileId(uri);
  if (fileId == null || fileId.isEmpty) return url;

  return Uri.https(
    'drive.usercontent.google.com',
    '/download',
    {
      'id': fileId,
      'export': 'download',
      'confirm': 't',
    },
  ).toString();
}

String? backendProxyVideoUrl(String value) {
  final url = value.trim();
  if (url.isEmpty) return null;

  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final fileId = _googleDriveFileId(uri);
  if (fileId == null || fileId.isEmpty) return null;

  return absoluteBackendUrl('/media/videos/$fileId');
}

bool isGoogleDriveVideoUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) return false;
  final host = uri.host.toLowerCase();
  return host.endsWith('drive.google.com') ||
      host.endsWith('drive.usercontent.google.com') ||
      host.endsWith('docs.google.com');

}

String? resolvePrimaryVideoPlayUrl({
  required String videoUrl,
  required String videoAsset,
}) {
  final proxyUrl = backendProxyVideoUrl(videoUrl);
  if (proxyUrl != null) return proxyUrl;

  final backendAssetUrl = backendVideoUrl(videoAsset);
  if (backendAssetUrl != null) return backendAssetUrl;

  final directUrl = normalizePlayableVideoUrl(videoUrl);
  if (directUrl.isNotEmpty) return directUrl;

  if (isBundledVideoAsset(videoAsset)) return videoAsset.trim();
  return null;
}

bool hasPlayableVideoSource({
  required String videoAsset,
  required String videoUrl,
  String frontVideoUrl = '',
  String leftVideoUrl = '',
  String rightVideoUrl = '',
}) {
  return normalizePlayableVideoUrl(videoUrl).isNotEmpty ||
      normalizePlayableVideoUrl(frontVideoUrl).isNotEmpty ||
      normalizePlayableVideoUrl(leftVideoUrl).isNotEmpty ||
      normalizePlayableVideoUrl(rightVideoUrl).isNotEmpty ||
      backendVideoUrl(videoAsset) != null ||
      isBundledVideoAsset(videoAsset);
}

String? backendVideoUrl(String value) {
  final path = value.trim();
  if (path.isEmpty || _isLegacyExcludedAsset(path)) return null;
  return absoluteBackendUrl(path);
}

bool isBundledVideoAsset(String value) {
  final asset = value.trim();
  if (asset.isEmpty) return false;

  final uri = Uri.tryParse(asset);
  if (uri != null && uri.hasScheme) return false;

  final lower = asset.toLowerCase();
  if (!lower.startsWith('assets/')) return false;

  // The current APK excludes the old video-heavy asset folders, so only
  // explicitly bundled lesson videos should be attempted through Flutter assets.
  return lower.startsWith('assets/tutorial_videos/') ||
      lower.startsWith('assets/videos/');
}

bool _isLegacyExcludedAsset(String value) {
  final lower = value.trim().toLowerCase();
  return lower.startsWith('assets/') && !isBundledVideoAsset(value);
}

String? absoluteBackendUrl(String pathOrUrl) {
  final value = pathOrUrl.trim();
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;

  final baseUrl = ApiConfig.baseUrl;
  if (baseUrl.isEmpty) return null;

  final baseUri = Uri.tryParse(baseUrl);
  if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
    return null;
  }

  final cleanBase =
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  if (value.startsWith('/')) return '$cleanBase$value';

  final encodedPath = value.split('/').map(Uri.encodeComponent).join('/');
  return '$cleanBase/$encodedPath';
}

String? _googleDriveFileId(Uri uri) {
  final id = uri.queryParameters['id'];
  if (id != null && id.trim().isNotEmpty) return id.trim();

  final segments = uri.pathSegments;
  final fileIndex = segments.indexOf('file');
  if (fileIndex != -1 &&
      segments.length > fileIndex + 2 &&
      segments[fileIndex + 1] == 'd') {
    return segments[fileIndex + 2].trim();
  }

  final dIndex = segments.indexOf('d');
  if (dIndex != -1 && segments.length > dIndex + 1) {
    return segments[dIndex + 1].trim();
  }

  return null;
}
