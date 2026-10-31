import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sign_language_app/services/video_player_service.dart';
import 'package:sign_language_app/utils/video_url_utils.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:8080');
  });

  test('180 video assets are recognized as bundled videos', () {
    const assetPath = 'assets/180_videos/Road.mp4';

    expect(isBundledVideoAsset(assetPath), isTrue);

    final sources = VideoPlayerService.buildSources(
      videoUrl: '',
      videoAsset: assetPath,
    );
    expect(
      sources.any((source) => source.value == assetPath && !source.isNetwork),
      isTrue,
    );
  });

  test('other legacy assets are not treated as bundled lesson videos', () {
    expect(isBundledVideoAsset('assets/Alpha.mp4'), isFalse);
  });
}
