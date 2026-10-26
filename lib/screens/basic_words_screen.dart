import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/basic_word.dart';
import '../services/background_music_service.dart';
import '../services/basic_word_service.dart';
import '../services/progress_service.dart';
import '../ui/background_music_region.dart';
import '../ui/app_shell.dart';
import '../utils/url_helper.dart';
import '../utils/video_url_utils.dart';
import '../widgets/transparent_sign_video_overlay.dart';
import 'sign_detector_screen.dart';
import 'tutorial_video_screen.dart';

// ── Colour tokens ─────────────────────────────────────────────────────────────
const kVividBlue = Color(0xFF1500C8);
const kAccent = Color(0xFF11B7CB);
const kGreen = Color(0xFF34C759);

const Set<String> _excludedBasicWordCategories = {
  'alphabet',
  'alphabets',
  'number',
  'numbers',
};

// ── Sign language sets ──────────────────────────────────────────────────────
// Categories shown when the user switches the toggle to "FSL Signs".
const Map<String, IconData> _categoryIcons = {
  'Animal': Icons.pets_rounded,
  'Color': Icons.palette_outlined,
  'Days of the week': Icons.calendar_view_week_outlined,
  'Direction and Location': Icons.explore_outlined,
  'Emotion': Icons.sentiment_satisfied_alt_outlined,
  'Emotions': Icons.sentiment_satisfied_alt_outlined,
  'Environment': Icons.park_outlined,
  'Family': Icons.family_restroom_rounded,
  'Feelings': Icons.favorite_border_rounded,
  'Food': Icons.restaurant_outlined,
  'Food Taste': Icons.local_dining_outlined,
  'Fruits': Icons.apple_outlined,
  'Greetings': Icons.waving_hand_outlined,
  'Health and Emergency': Icons.medical_services_outlined,
  'Kitchenware': Icons.blender_outlined,
  'Money and Shopping': Icons.shopping_cart_outlined,
  'Months': Icons.calendar_month_outlined,
  'NOT EDIT': Icons.block_outlined,
  'Not Edited': Icons.block_outlined,
  'Operations': Icons.calculate_outlined,
  'Person': Icons.person_outline_rounded,
  'Personal Things': Icons.person_outline_rounded,
  'Questions': Icons.help_outline_rounded,
  'Religion and Values': Icons.auto_awesome_outlined,
  'Responses and Reactions': Icons.thumbs_up_down_outlined,
  'School': Icons.school_outlined,
  'School Supply': Icons.backpack_outlined,
  'Shape': Icons.category_outlined,
  'Technology and Communication': Icons.devices_outlined,
  'Temperature': Icons.thermostat_rounded,
  'Time': Icons.schedule_outlined,
  'Transportation': Icons.directions_car_outlined,
};

class BasicWordsScreen extends StatefulWidget {
  final String userName;

  const BasicWordsScreen({
    super.key,
    required this.userName,
  });

  @override
  State<BasicWordsScreen> createState() => _BasicWordsScreenState();
}

class _BasicWordsScreenState extends State<BasicWordsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late Future<List<BasicWord>> _wordFuture;
  String _query = '';

  // null = show category landing grid; non-null = show word list for that category
  String? _selectedCategory;

  Future<void> _recordLearned(BasicWord word) async {
    try {
      await ProgressService().recordActivity(
        category: 'basic_word',
        itemKey: word.key,
      );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _wordFuture = BasicWordService().listBasicWords();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      setState(() {
        _query = q;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _wordFuture = BasicWordService().listBasicWords();
      });

  bool _isBasicWordCategory(BasicWord word) {
    return !_excludedBasicWordCategories.contains(
      word.category.trim().toLowerCase(),
    );
  }

  List<String> _categories(List<BasicWord> words) {
    final playableWords = words
        .where((word) => _isBasicWordCategory(word) && _hasTutorialVideo(word))
        .toList();
    final cats = <String>{};
    for (final w in playableWords) {
      if (w.category.trim().isNotEmpty) cats.add(w.category);
    }
    return cats.toList()..sort();
  }

  List<BasicWord> _wordsForCategory(
          List<BasicWord> words, String category) =>
      words
          .where((w) =>
              _isBasicWordCategory(w) &&
              w.category == category &&
              _hasTutorialVideo(w))
          .toList();

  List<BasicWord> _searchResults(List<BasicWord> words) {
    if (_query.isEmpty) return [];
    return words.where((w) {
      if (!_isBasicWordCategory(w)) return false;
      if (!_hasTutorialVideo(w)) return false;
      return w.title.toLowerCase().contains(_query) ||
          w.category.toLowerCase().contains(_query) ||
          w.description.toLowerCase().contains(_query);
    }).toList();
  }

  bool _hasTutorialVideo(BasicWord word) {
    return hasPlayableVideoSource(
      videoAsset: word.videoAsset,
      videoUrl: word.videoUrl,
      frontVideoUrl: word.frontVideoUrl,
      leftVideoUrl: word.leftVideoUrl,
      rightVideoUrl: word.rightVideoUrl,
    );
  }

  void _openVideo(BasicWord word) {
    if (!_hasTutorialVideo(word)) return;
    _recordLearned(word);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TutorialVideoScreen(
        title: word.title,
        imageAsset: word.imageAsset,
        imageUrl: word.imageUrl,
        videoAsset: word.videoAsset,
        videoUrl: word.videoUrl,
        frontVideoUrl: word.frontVideoUrl,
        leftVideoUrl: word.leftVideoUrl,
        rightVideoUrl: word.rightVideoUrl,
        activityCategory: 'basic_word',
      ),
    ));
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Basic Words',
      ),
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: AppBackground(
          imageAsset: 'assets/NEW BACKGROUND/new basic words.png',
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: _FloatingBubbles(),
                ),
              ),
              SafeArea(
                child: FutureBuilder<List<BasicWord>>(
                  future: _wordFuture,
                  builder: (context, snapshot) {
                    final words = snapshot.data ?? [];
                    final categories = _categories(words);
                    final isLoading =
                        snapshot.connectionState == ConnectionState.waiting;
                    final hasError = snapshot.hasError;

                    return Column(
                      children: [
                        AppTopBar(
                          onBack: _selectedCategory != null
                              ? () => setState(() => _selectedCategory = null)
                              : () => Navigator.of(context).pop(),
                          onMenu: () =>
                              _scaffoldKey.currentState?.openEndDrawer(),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 2, bottom: 14),
                          child: Text(
                            'BASIC WORDS',
                            style: TextStyle(
                              color: Color(0xFF1500C8),
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),

                        // ── Search bar ────────────────────────────────────────────
                        SizedBox(
                          height: math.max(
                            44.0,
                            MediaQuery.sizeOf(context).height * 0.055,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(32),
                                      border: Border.all(
                                        color: _query.isNotEmpty
                                            ? kVividBlue
                                            : const Color(0xFFCCCCCC),
                                        width: 1.8,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 9),
                                          child: Icon(
                                            Icons.search_rounded,
                                            color: Color(0xFF9DA4AD),
                                            size: 24,
                                          ),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            focusNode: _searchFocusNode,
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            decoration: const InputDecoration(
                                              hintText: 'Search words..',
                                              hintStyle: TextStyle(
                                                color: Color(0xFF626B75),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 0,
                                                      vertical: 9),
                                            ),
                                          ),
                                        ),
                                        if (_query.isNotEmpty)
                                          GestureDetector(
                                            onTap: _clearSearch,
                                            child: const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 18),
                                              child: Icon(
                                                Icons.close_rounded,
                                                color: Color(0xFF9DA4AD),
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Practice button — compact and responsive: scales
                                // with screen width (capped) so it stays small on
                                // phones but doesn't look cramped on tablets, while
                                // the search bar keeps the majority of the space.
                                SizedBox(
                                  width: math.min(
                                    120.0,
                                    math.max(
                                      108.0,
                                      MediaQuery.sizeOf(context).width * 0.24,
                                    ),
                                  ),
                                  child: Material(
                                    color: kGreen,
                                    borderRadius: BorderRadius.circular(32),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context)
                                            .push(MaterialPageRoute(
                                          builder: (_) =>
                                              const SignDetectorScreen(
                                            initialMode: DetectionMode.words,
                                            lockMode: true,
                                            captureKind: CaptureKind.video,
                                            title: 'Basic Word Practice',
                                          ),
                                        ));
                                      },
                                      borderRadius: BorderRadius.circular(32),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        alignment: Alignment.center,
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  'Practice',
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14), // lowers Basic.mp4 a bit
                        const SizedBox(
                          height: 120,
                          width: 240,
                          child: TransparentSignVideoOverlay(
                            videoAsset: 'assets/Basic.mp4',
                            fit: BoxFit.contain,
                            volume: 0,
                            threshold: 0.34,
                            smoothing: 0.08,
                          ),
                        ),

                        const SizedBox(height: 2),

                        // ── Main content ──────────────────────────────────────────
                        Expanded(
                          child: isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white))
                              : hasError
                                  ? _ErrorState(
                                      message:
                                          'Cannot load basic words. Make sure the backend is running.',
                                      onRetry: _reload,
                                    )
                                  : _query.isNotEmpty
                                      ? _buildSearchResults(
                                          _searchResults(words), categories)
                                      : _selectedCategory == null
                                          ? _buildCategoryGrid(
                                              categories, words)
                                          : _buildWordList(
                                              _wordsForCategory(
                                                  words, _selectedCategory!),
                                              _selectedCategory!,
                                            ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Category selection grid (Image 1) ──────────────────────────────────────
  Widget _buildCategoryGrid(List<String> categories, List<BasicWord> allWords) {
    // Count words per category for badge
    final wordCount = <String, int>{};
    for (final w in allWords.where(
      (word) => _isBasicWordCategory(word) && _hasTutorialVideo(word),
    )) {
      wordCount[w.category] = (wordCount[w.category] ?? 0) + 1;
    }

    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 21, top: 7),
              child: Text(
                'Categories',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const columns = 3;
                  const spacing = 10.0;
                  final itemWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  final textScaler = MediaQuery.textScalerOf(context);
                  final widestWord = categories
                      .expand((category) => category.split(RegExp(r'\s+')))
                      .fold<double>(0, (widest, word) {
                    final painter = TextPainter(
                      text: TextSpan(
                        text: word,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: textScaler,
                      maxLines: 1,
                    )..layout();
                    return math.max(widest, painter.width);
                  });
                  final categoryFontSize = 16 *
                      math
                          .max(
                            0.01,
                            math.min(1.0, (itemWidth - 8) / widestWord),
                          )
                          .toDouble();

                  return GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      final icon =
                          _categoryIcons[cat] ?? Icons.category_outlined;
                      final count = wordCount[cat] ?? 0;
                      return _CategoryTile(
                        label: cat,
                        icon: icon,
                        count: count,
                        fontSize: categoryFontSize,
                        onTap: () {
                          _searchFocusNode.unfocus();
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Word list for a selected category ──────────────────────────────────────
  Widget _buildWordList(List<BasicWord> words, String category) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 14, 15, 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color:
              const Color.fromARGB(181, 88, 170, 248).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color.fromARGB(255, 156, 156, 156)
                .withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _categoryIcons[category] ?? Icons.category_outlined,
                    color: const Color.fromARGB(255, 14, 0, 137),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        category,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (words.isEmpty)
                _EmptyCategory(category: category, hasQuery: false)
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 9.0;
                    const columns = 3;
                    final itemWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: 12,
                      children: words
                          .map((word) => SizedBox(
                                width: itemWidth,
                                height: 160,
                                child: _BasicWordCard(
                                  word: word,
                                  showCategory: false,
                                  onView: () => _showWordDetails(context, word),
                                  onWatch: () => _openVideo(word),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filtered results grouped as category sections while searching ──────────
  Widget _buildSearchResults(List<BasicWord> results, List<String> categories) {
    if (results.isEmpty) {
      return const _EmptyCategory(category: '', hasQuery: true);
    }

    final byCategory = <String, List<BasicWord>>{};
    for (final w in results) {
      byCategory.putIfAbsent(w.category, () => []).add(w);
    }
    final orderedCats = categories.where(byCategory.containsKey).toList();
    for (final c in byCategory.keys) {
      if (!orderedCats.contains(c)) orderedCats.add(c);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 14, 15, 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color:
              const Color.fromARGB(181, 88, 170, 248).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color.fromARGB(255, 156, 156, 156)
                .withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          children: [
            for (final cat in orderedCats) ...[
              Row(
                children: [
                  Icon(
                    _categoryIcons[cat] ?? Icons.category_outlined,
                    color: const Color.fromARGB(255, 14, 0, 137),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cat,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 9.0;
                  const columns = 3;
                  final itemWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 12,
                    children: byCategory[cat]!
                        .map((word) => SizedBox(
                              width: itemWidth,
                              height: 160,
                              child: _BasicWordCard(
                                word: word,
                                showCategory: false,
                                onView: () => _showWordDetails(context, word),
                                onWatch: () => _openVideo(word),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  void _showWordDetails(BuildContext context, BasicWord word) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 38),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kAccent, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          word.title,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            color: Color(0xFF071A3F),
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 190,
                      width: double.infinity,
                      child: _WordThumbnail(word: word),
                    ),
                    if (word.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                        child: Text(
                          word.description,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: const TextStyle(
                            color: Color(0xFF071A3F),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: const Color(0xFF11B7CB),
                      child: Center(
                        child: _TutorialButton(
                          label: 'VIDEO TUTORIAL',
                          onTap: () {
                            Navigator.of(context).pop();
                            _openVideo(word);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Material(
                  color: const Color(0xFFFF2F2F),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Category tile for the grid landing ────────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final double fontSize;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.count,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBBDDBB), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                    width: 1.2),
              ),
              child: Icon(icon, size: 24, color: const Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 0,
              children: label
                  .split(RegExp(r'\s+'))
                  .map(
                    (word) => Text(
                      word,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: const Color(0xFF2E7D32),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BasicWordCard extends StatelessWidget {
  final BasicWord word;
  final VoidCallback onView;
  final VoidCallback onWatch;
  final bool showCategory;

  const _BasicWordCard({
    required this.word,
    required this.onView,
    required this.onWatch,
    this.showCategory = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFD7FF), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30185FA5),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: Color(0x15000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFEFF6FF),
                  child: _WordThumbnail(word: word),
                ),
              ),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF185FA5), Color(0xFF0B8FFF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showCategory) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _categoryIcons[word.category] ??
                                  Icons.category_outlined,
                              color: Colors.white,
                              size: 9,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  word.category,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        word.title,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const SizedBox(width: 6),
                        Expanded(
                          child: _TinyAction(
                            label: 'Watch',
                            icon: Icons.play_circle_outline_rounded,
                            onTap: onWatch,
                            color: const Color(0xFF1E8C3A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _TinyAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = kVividBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 11),
              const SizedBox(width: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Lightweight static thumbnail — no video init on list, keeps UI fast
class _WordThumbnail extends StatelessWidget {
  final BasicWord word;
  const _WordThumbnail({required this.word});

  @override
  Widget build(BuildContext context) {
    if (word.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: getOptimizedUrl(word.imageUrl, width: 400),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => _PlaceholderThumb(title: word.title),
      );
    }
    if (word.imageAsset.isNotEmpty) {
      return Image.asset(
        word.imageAsset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _PlaceholderThumb(title: word.title),
      );
    }
    // Video-only word: show a static play placeholder — no VideoPlayerController
    return _PlaceholderThumb(title: word.title, showPlay: true);
  }
}

class _PlaceholderThumb extends StatelessWidget {
  final String title;
  final bool showPlay;
  const _PlaceholderThumb({required this.title, this.showPlay = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFDCEDFF),
      child: showPlay
          ? Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF185FA5).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Color(0xFF185FA5),
                  size: 32,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _TutorialButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TutorialButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2A8E8),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 156,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF72326E), width: 2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  final String category;
  final bool hasQuery;

  const _EmptyCategory({
    required this.category,
    required this.hasQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Text(
        hasQuery
            ? 'No basic words match your search.'
            : 'No videos in $category yet.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: const Color.fromARGB(255, 20, 74, 190),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black, width: 1.4),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Decorative floating bubbles for the background ──────────────────────────
// Purely visual, non-interactive layer — sits behind all existing screen
// content and does not change any other part of the design.
const List<Color> _bubbleColors = [
  kVividBlue,
  kAccent,
  kGreen,
  Color(0xFF0B8FFF),
  Color(0xFF9C27B0),
];

class _BubbleSpec {
  final double dx; // horizontal anchor, 0..1 fraction of width
  final double size;
  final double speed; // relative rise speed
  final double phase; // 0..1 start offset so bubbles don't move in sync
  final double wobble; // horizontal sway amount in logical pixels
  final Color color;
  final bool outline; // some bubbles are soft rings instead of filled dots

  const _BubbleSpec({
    required this.dx,
    required this.size,
    required this.speed,
    required this.phase,
    required this.wobble,
    required this.color,
    required this.outline,
  });
}

class _FloatingBubbles extends StatefulWidget {
  const _FloatingBubbles();

  @override
  State<_FloatingBubbles> createState() => _FloatingBubblesState();
}

class _FloatingBubblesState extends State<_FloatingBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_BubbleSpec> _bubbles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();

    // Fixed seed so the layout is stable across rebuilds/hot reloads
    // instead of jumping to a new random arrangement every time.
    final rnd = math.Random(7);
    _bubbles = List.generate(16, (i) {
      final color = _bubbleColors[rnd.nextInt(_bubbleColors.length)];
      return _BubbleSpec(
        dx: rnd.nextDouble(),
        size: 14 + rnd.nextDouble() * 46,
        speed: 0.45 + rnd.nextDouble() * 0.85,
        phase: rnd.nextDouble(),
        wobble: 8 + rnd.nextDouble() * 18,
        color: color,
        outline: rnd.nextDouble() < 0.4,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = constraints.biggest;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: canvasSize,
              painter: _BubblesPainter(
                bubbles: _bubbles,
                progress: _controller.value,
              ),
            );
          },
        );
      },
    );
  }
}

class _BubblesPainter extends CustomPainter {
  final List<_BubbleSpec> bubbles;
  final double progress;

  _BubblesPainter({required this.bubbles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    for (final b in bubbles) {
      // t travels 0 -> 1 -> 0 (loops) at each bubble's own speed/offset.
      final t = (progress * b.speed + b.phase) % 1.0;
      final y = size.height * (1 - t);
      final wobbleX = math.sin((t * 2 * math.pi) + b.phase * 10) * b.wobble;
      final x = size.width * b.dx + wobbleX;
      final radius = b.size / 2;

      // Fades in near the bottom, fades out near the top so bubbles never
      // pop in/out abruptly.
      final envelope = math.sin(math.pi * t).clamp(0.0, 1.0);
      final opacity = 0.08 + 0.16 * envelope;

      if (b.outline) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = b.color.withValues(alpha: opacity * 1.6);
        canvas.drawCircle(Offset(x, y), radius, ring);
      } else {
        final fill = Paint()
          ..style = PaintingStyle.fill
          ..color = b.color.withValues(alpha: opacity);
        canvas.drawCircle(Offset(x, y), radius, fill);
      }

      // Tiny glossy highlight so bubbles read as bubbles, not flat dots.
      final highlight = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: opacity * 1.4);
      canvas.drawCircle(
        Offset(x - radius * 0.32, y - radius * 0.32),
        radius * 0.22,
        highlight,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
