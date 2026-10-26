// =============================================================
//  guess_me_screen.dart  –  "Guess Me?" The Ultimate Guessing Game
//  Single-file, production-ready Flutter widget.
//  No external dependencies beyond Flutter core.
//
//  _AnimatedQuestionCanvas replaces the video player until your
//  .mp4 files are ready.  Search "SWAP FOR VIDEO" to find the
//  exact widget to replace.
// =============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/background_music_service.dart';
import '../ui/background_music_region.dart';
import '../ui/app_shell.dart';
import '../widgets/video_player_with_controls.dart';

// ─────────────────────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GuessMeApp());
}

class GuessMeApp extends StatelessWidget {
  const GuessMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guess Me?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: const GuessMeScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────
class Question {
  /// Identifies the question; maps to an emoji now, a video asset later.
  final String prompt;
  final List<String> options;
  final String correctAnswer;

  Question({
    required this.prompt,
    required this.options,
    required this.correctAnswer,
  });
}

// ─────────────────────────────────────────────────────────────
//  QUESTION DATA
// ─────────────────────────────────────────────────────────────
List<Question> buildQuestionList() {
  final questions = [
    Question(
      prompt: 'assets/guess_me/videos/how_are_you.mp4',
      options: ['How Are You', 'Thank You', 'Good Night'],
      correctAnswer: 'How Are You',
    ),
    Question(
      prompt: 'assets/guess_me/videos/see_you_later.mp4',
      options: ['See You Later', 'Good Morning', 'Good Night'],
      correctAnswer: 'See You Later',
    ),
    Question(
      prompt: 'assets/guess_me/videos/how_are_you_1.mp4',
      options: ['How Are You', 'How Old Are You', 'What Is Your Name'],
      correctAnswer: 'How Are You',
    ),
    Question(
      prompt: 'assets/guess_me/videos/see_you_1.mp4',
      options: ['See You', 'See You Later', 'Goodbye'],
      correctAnswer: 'See You',
    ),
    Question(
      prompt: 'assets/guess_me/videos/i_love_you.mp4',
      options: ['I Hate You', 'I Love You', 'I Miss You'],
      correctAnswer: 'I Love You',
    ),
    Question(
      prompt: 'assets/guess_me/videos/helloo.mp4',
      options: ['Hello', 'Bye', 'Goodbye'],
      correctAnswer: 'Hello',
    ),
    Question(
      prompt: 'assets/guess_me/videos/byee.mp4',
      options: ['Bye', 'Hello', 'Thanks'],
      correctAnswer: 'Bye',
    ),
    Question(
      prompt: 'assets/guess_me/videos/ty.mp4',
      options: ['Thank You', 'Sorry', 'Excuse Me'],
      correctAnswer: 'Thank You',
    ),
    Question(
      prompt: 'assets/guess_me/videos/excusemee.mp4',
      options: ['Excuse Me', 'Please', 'Sorry'],
      correctAnswer: 'Excuse Me',
    ),
    Question(
      prompt: 'assets/guess_me/videos/takecare.mp4',
      options: ['Take Care', 'Good Luck', 'See You Later'],
      correctAnswer: 'Take Care',
    ),
    Question(
      prompt: 'assets/guess_me/videos/congratulationss.mp4',
      options: ['Congratulations', 'Good Morning', 'Hello'],
      correctAnswer: 'Congratulations',
    ),
    Question(
      prompt: 'assets/guess_me/videos/goooodluckk.mp4',
      options: ['Good Luck', 'Good Night', 'Bye'],
      correctAnswer: 'Good Luck',
    ),
    Question(
      prompt: 'assets/guess_me/videos/housee.mp4',
      options: ['House', 'Church', 'Bridge'],
      correctAnswer: 'House',
    ),
    Question(
      prompt: 'assets/guess_me/videos/bridgee.mp4',
      options: ['Bridge', 'Garden', 'Door'],
      correctAnswer: 'Bridge',
    ),
    Question(
      prompt: 'assets/guess_me/videos/churchh.mp4',
      options: ['Church', 'Farm', 'Park'],
      correctAnswer: 'Church',
    ),
    Question(
      prompt: 'assets/guess_me/videos/farmm.mp4',
      options: ['Farm', 'Mountain', 'Cloud'],
      correctAnswer: 'Farm',
    ),
    Question(
      prompt: 'assets/guess_me/videos/ceilingg.mp4',
      options: ['Ceiling', 'Floor', 'Window'],
      correctAnswer: 'Ceiling',
    ),
    Question(
      prompt: 'assets/guess_me/videos/doorr.mp4',
      options: ['Door', 'Chair', 'Table'],
      correctAnswer: 'Door',
    ),
    Question(
      prompt: 'assets/guess_me/videos/FLOORR.mp4',
      options: ['Floor', 'Ceiling', 'Wall'],
      correctAnswer: 'Floor',
    ),
    Question(
      prompt: 'assets/guess_me/videos/GRASSS.mp4',
      options: ['Grass', 'Moon', 'Rain'],
      correctAnswer: 'Grass',
    ),
    Question(
      prompt: 'assets/guess_me/videos/parkk.mp4',
      options: ['Park', 'Garden', 'Market'],
      correctAnswer: 'Park',
    ),
    Question(
      prompt: 'assets/guess_me/videos/moonn.mp4',
      options: ['Moon', 'Sun', 'Star'],
      correctAnswer: 'Moon',
    ),
    Question(
      prompt: 'assets/guess_me/videos/plantt.mp4',
      options: ['Plant', 'Flower', 'Tree'],
      correctAnswer: 'Plant',
    ),
    Question(
      prompt: 'assets/guess_me/videos/mountainn.mp4',
      options: ['Mountain', 'River', 'Hill'],
      correctAnswer: 'Mountain',
    ),
    Question(
      prompt: 'assets/guess_me/videos/rainn.mp4',
      options: ['Rain', 'Snow', 'Cloud'],
      correctAnswer: 'Rain',
    ),
    Question(
      prompt: 'assets/guess_me/videos/buildingg.mp4',
      options: ['Building', 'Bridge', 'House'],
      correctAnswer: 'Building',
    ),
    Question(
      prompt: 'assets/guess_me/videos/cloudd.mp4',
      options: ['Cloud', 'Rain', 'Sun'],
      correctAnswer: 'Cloud',
    ),
    Question(
      prompt: 'assets/guess_me/videos/firee.mp4',
      options: ['Fire', 'Water', 'Smoke'],
      correctAnswer: 'Fire',
    ),
    Question(
      prompt: 'assets/guess_me/videos/flowerr.mp4',
      options: ['Flower', 'Plant', 'Grass'],
      correctAnswer: 'Flower',
    ),
    Question(
      prompt: 'assets/guess_me/videos/gatee.mp4',
      options: ['Gate', 'Door', 'Window'],
      correctAnswer: 'Gate',
    ),
    Question(
      prompt: 'assets/guess_me/videos/lightt.mp4',
      options: ['Light', 'Shadow', 'Dark'],
      correctAnswer: 'Light',
    ),
    Question(
      prompt: 'assets/guess_me/videos/pooll.mp4',
      options: ['Pool', 'Lake', 'Sea'],
      correctAnswer: 'Pool',
    ),
    Question(
      prompt: 'assets/guess_me/videos/markett.mp4',
      options: ['Market', 'Park', 'Office'],
      correctAnswer: 'Market',
    ),
    Question(
      prompt: 'assets/guess_me/videos/bedroom1.mp4',
      options: ['Bedroom', 'Bathroom', 'Kitchen'],
      correctAnswer: 'Bedroom',
    ),
    Question(
      prompt: 'assets/guess_me/videos/bathroom1.mp4',
      options: ['Bathroom', 'Bedroom', 'Living Room'],
      correctAnswer: 'Bathroom',
    ),
    Question(
      prompt: 'assets/guess_me/videos/kitchenn.mp4',
      options: ['Kitchen', 'Bedroom', 'Bathroom'],
      correctAnswer: 'Kitchen',
    ),
    Question(
      prompt: 'assets/guess_me/videos/living_room.mp4',
      options: ['Living Room', 'Kitchen', 'Bedroom'],
      correctAnswer: 'Living Room',
    ),
    Question(
      prompt: 'assets/guess_me/videos/elevatorr.mp4',
      options: ['Elevator', 'Stairs', 'Escalator'],
      correctAnswer: 'Elevator',
    ),
    Question(
      prompt: 'assets/guess_me/videos/hospitall.mp4',
      options: ['Hospital', 'School', 'Hotel'],
      correctAnswer: 'Hospital',
    ),
    Question(
      prompt: 'assets/guess_me/videos/gardenn.mp4',
      options: ['Garden', 'Park', 'Farm'],
      correctAnswer: 'Garden',
    ),
    Question(
      prompt: 'assets/guess_me/videos/beautiful.mp4',
      options: ['Beautiful', 'Ugly', 'Bright'],
      correctAnswer: 'Beautiful',
    ),
    Question(
      prompt: 'assets/guess_me/videos/uglyy.mp4',
      options: ['Ugly', 'Beautiful', 'Small'],
      correctAnswer: 'Ugly',
    ),
    Question(
      prompt: 'assets/guess_me/videos/beach.mp4',
      options: ['Beach', 'Sea', 'Pool'],
      correctAnswer: 'Beach',
    ),
    Question(
      prompt: 'assets/guess_me/videos/baldl.mp4',
      options: ['Bald', 'Hairy', 'Curly'],
      correctAnswer: 'Bald',
    ),
    Question(
      prompt: 'assets/guess_me/videos/clapp.mp4',
      options: ['Clap', 'Jump', 'Dance'],
      correctAnswer: 'Clap',
    ),
    Question(
      prompt: 'assets/guess_me/videos/chairr.mp4',
      options: ['Chair', 'Table', 'Bed'],
      correctAnswer: 'Chair',
    ),
    Question(
      prompt: 'assets/guess_me/videos/mudd.mp4',
      options: ['Mud', 'Sand', 'Water'],
      correctAnswer: 'Mud',
    ),
    Question(
      prompt: 'assets/guess_me/videos/applee.mp4',
      options: ['Apple', 'Banana', 'Orange'],
      correctAnswer: 'Apple',
    ),
    Question(
      prompt: 'assets/guess_me/videos/bananaa.mp4',
      options: ['Banana', 'Apple', 'Grape'],
      correctAnswer: 'Banana',
    ),
    Question(
      prompt: 'assets/guess_me/videos/breadd.mp4',
      options: ['Bread', 'Cake', 'Rice'],
      correctAnswer: 'Bread',
    ),
    Question(
      prompt: 'assets/guess_me/videos/burgerr.mp4',
      options: ['Burger', 'Pizza', 'Sandwich'],
      correctAnswer: 'Burger',
    ),
    Question(
      prompt: 'assets/guess_me/videos/cakee.mp4',
      options: ['Cake', 'Bread', 'Cookie'],
      correctAnswer: 'Cake',
    ),
    Question(
      prompt: 'assets/guess_me/videos/candyy.mp4',
      options: ['Candy', 'Chocolate', 'Cake'],
      correctAnswer: 'Candy',
    ),
    Question(
      prompt: 'assets/guess_me/videos/chocolatee.mp4',
      options: ['Chocolate', 'Candy', 'Cake'],
      correctAnswer: 'Chocolate',
    ),
    Question(
      prompt: 'assets/guess_me/videos/cookiee.mp4',
      options: ['Cookie', 'Cake', 'Bread'],
      correctAnswer: 'Cookie',
    ),
    Question(
      prompt: 'assets/guess_me/videos/eggg.mp4',
      options: ['Egg', 'Milk', 'Cheese'],
      correctAnswer: 'Egg',
    ),
    Question(
      prompt: 'assets/guess_me/videos/FRUITT.mp4',
      options: ['Fruit', 'Vegetable', 'Meat'],
      correctAnswer: 'Fruit',
    ),
    Question(
      prompt: 'assets/guess_me/videos/GRAPESS.mp4',
      options: ['Grapes', 'Apple', 'Banana'],
      correctAnswer: 'Grapes',
    ),
    Question(
      prompt: 'assets/guess_me/videos/ICE CREAMM.mp4',
      options: ['Ice Cream', 'Cake', 'Yogurt'],
      correctAnswer: 'Ice Cream',
    ),
    Question(
      prompt: 'assets/guess_me/videos/MEATT.mp4',
      options: ['Meat', 'Fruit', 'Vegetable'],
      correctAnswer: 'Meat',
    ),
    Question(
      prompt: 'assets/guess_me/videos/NOODLESS.mp4',
      options: ['Noodles', 'Rice', 'Soup'],
      correctAnswer: 'Noodles',
    ),
    Question(
      prompt: 'assets/guess_me/videos/onionn.mp4',
      options: ['Onion', 'Garlic', 'Pepper'],
      correctAnswer: 'Onion',
    ),
    Question(
      prompt: 'assets/guess_me/videos/pizzaa.mp4',
      options: ['Pizza', 'Burger', 'Sandwich'],
      correctAnswer: 'Pizza',
    ),
    Question(
      prompt: 'assets/guess_me/videos/RAINBOWW.mp4',
      options: ['Rainbow', 'Cloud', 'Sun'],
      correctAnswer: 'Rainbow',
    ),
    Question(
      prompt: 'assets/guess_me/videos/RIVERR.mp4',
      options: ['River', 'Road', 'Rock'],
      correctAnswer: 'River',
    ),
    Question(
      prompt: 'assets/guess_me/videos/ROADD.mp4',
      options: ['Road', 'River', 'Roof'],
      correctAnswer: 'Road',
    ),
    Question(
      prompt: 'assets/guess_me/videos/ROCKK.mp4',
      options: ['Rock', 'River', 'Road'],
      correctAnswer: 'Rock',
    ),
    Question(
      prompt: 'assets/guess_me/videos/ROOFF.mp4',
      options: ['Roof', 'Wall', 'Door'],
      correctAnswer: 'Roof',
    ),
    Question(
      prompt: 'assets/guess_me/videos/saladd.mp4',
      options: ['Salad', 'Soup', 'Sandwich'],
      correctAnswer: 'Salad',
    ),
    Question(
      prompt: 'assets/guess_me/videos/sandwichh.mp4',
      options: ['Sandwich', 'Burger', 'Pizza'],
      correctAnswer: 'Sandwich',
    ),
    Question(
      prompt: 'assets/guess_me/videos/soupp.mp4',
      options: ['Soup', 'Salad', 'Noodles'],
      correctAnswer: 'Soup',
    ),
    Question(
      prompt: 'assets/guess_me/videos/vegetablee.mp4',
      options: ['Vegetable', 'Fruit', 'Meat'],
      correctAnswer: 'Vegetable',
    ),
    Question(
      prompt: 'assets/guess_me/videos/i_love_you_1.mp4',
      options: ['I Love You', 'I Hate You', 'I Miss You'],
      correctAnswer: 'I Love You',
    ),

    // ── Family ─────────────────────────────────────────────────
    Question(
      prompt: 'assets/guess_me/videos/Family/auntie.mp4',
      options: ['Auntie', 'Uncle', 'Cousin'],
      correctAnswer: 'Auntie',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/baby.mp4',
      options: ['Baby', 'Son', 'Daughter'],
      correctAnswer: 'Baby',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/brother.mp4',
      options: ['Brother', 'Sister', 'Cousin'],
      correctAnswer: 'Brother',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/cousin.mp4',
      options: ['Cousin', 'Brother', 'Nephew'],
      correctAnswer: 'Cousin',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/daughter.mp4',
      options: ['Daughter', 'Son', 'Sister'],
      correctAnswer: 'Daughter',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/grandmother.mp4',
      options: ['Grandmother', 'Grandfather', 'Auntie'],
      correctAnswer: 'Grandmother',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/Husband.mp4',
      options: ['Husband', 'Wife', 'Father'],
      correctAnswer: 'Husband',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/nephew.mp4',
      options: ['Nephew', 'Niece', 'Cousin'],
      correctAnswer: 'Nephew',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/ninang.mp4',
      options: ['Ninang', 'Ninong', 'Auntie'],
      correctAnswer: 'Ninang',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/sister.mp4',
      options: ['Sister', 'Brother', 'Cousin'],
      correctAnswer: 'Sister',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/son.mp4',
      options: ['Son', 'Daughter', 'Baby'],
      correctAnswer: 'Son',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Family/wife.mp4',
      options: ['Wife', 'Husband', 'Mother'],
      correctAnswer: 'Wife',
    ),

    // ── Environment ────────────────────────────────────────────
    Question(
      prompt: 'assets/guess_me/videos/Environment/Beach.mp4',
      options: ['Beach', 'Garden', 'Road'],
      correctAnswer: 'Beach',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Environment/Garden.mp4',
      options: ['Garden', 'House', 'Market'],
      correctAnswer: 'Garden',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Environment/House.mp4',
      options: ['House', 'Garden', 'Road'],
      correctAnswer: 'House',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Environment/Market.mp4',
      options: ['Market', 'Beach', 'House'],
      correctAnswer: 'Market',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Environment/Road.mp4',
      options: ['Road', 'Market', 'Garden'],
      correctAnswer: 'Road',
    ),

    // ── Emotion ────────────────────────────────────────────────
    Question(
      prompt: 'assets/guess_me/videos/Emotion/Angry.mp4',
      options: ['Angry', 'Happy', 'Scared'],
      correctAnswer: 'Angry',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Emotion/Confuse.mp4',
      options: ['Confused', 'Angry', 'Crazy'],
      correctAnswer: 'Confused',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Emotion/Crazy.mp4',
      options: ['Crazy', 'Confused', 'Hate'],
      correctAnswer: 'Crazy',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Emotion/Happy.mp4',
      options: ['Happy', 'Angry', 'Scared'],
      correctAnswer: 'Happy',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Emotion/Hate.mp4',
      options: ['Hate', 'Happy', 'Crazy'],
      correctAnswer: 'Hate',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Emotion/Scared.mp4',
      options: ['Scared', 'Angry', 'Happy'],
      correctAnswer: 'Scared',
    ),

    // ── Direction and Location ─────────────────────────────────
    Question(
      prompt: 'assets/guess_me/videos/Direction and Location/back.mp4',
      options: ['Back', 'Front', 'Up'],
      correctAnswer: 'Back',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Direction and Location/down.mp4',
      options: ['Down', 'Up', 'Near'],
      correctAnswer: 'Down',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Direction and Location/Front.mp4',
      options: ['Front', 'Back', 'Right'],
      correctAnswer: 'Front',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Direction and Location/Left.mp4',
      options: ['Left', 'Right', 'Near'],
      correctAnswer: 'Left',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Direction and Location/Near.mp4',
      options: ['Near', 'Far', 'Down'],
      correctAnswer: 'Near',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Direction and Location/Right.mp4',
      options: ['Right', 'Left', 'Up'],
      correctAnswer: 'Right',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Direction and Location/Up.mp4',
      options: ['Up', 'Down', 'Front'],
      correctAnswer: 'Up',
    ),

    // ── Color ──────────────────────────────────────────────────
    Question(
      prompt: 'assets/guess_me/videos/Color/black.mp4',
      options: ['Black', 'Brown', 'Blue'],
      correctAnswer: 'Black',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Color/blue.mp4',
      options: ['Blue', 'Green', 'Black'],
      correctAnswer: 'Blue',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Color/brown.mp4',
      options: ['Brown', 'Black', 'Orange'],
      correctAnswer: 'Brown',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Color/green.mp4',
      options: ['Green', 'Blue', 'Yellow'],
      correctAnswer: 'Green',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Color/orange.mp4',
      options: ['Orange', 'Yellow', 'Brown'],
      correctAnswer: 'Orange',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Color/yellow.mp4',
      options: ['Yellow', 'Orange', 'Green'],
      correctAnswer: 'Yellow',
    ),

    // ── Alphabet ───────────────────────────────────────────────
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/A.mp4',
      options: ['A', 'C', 'E'],
      correctAnswer: 'A',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/C.mp4',
      options: ['C', 'A', 'G'],
      correctAnswer: 'C',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/E.mp4',
      options: ['E', 'A', 'I'],
      correctAnswer: 'E',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/G.mp4',
      options: ['G', 'C', 'J'],
      correctAnswer: 'G',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/H.mp4',
      options: ['H', 'N', 'I'],
      correctAnswer: 'H',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/I.mp4',
      options: ['I', 'E', 'J'],
      correctAnswer: 'I',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/J.mp4',
      options: ['J', 'G', 'L'],
      correctAnswer: 'J',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/L.mp4',
      options: ['L', 'J', 'N'],
      correctAnswer: 'L',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/N.mp4',
      options: ['N', 'H', 'P'],
      correctAnswer: 'N',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/P.mp4',
      options: ['P', 'N', 'V'],
      correctAnswer: 'P',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/V.mp4',
      options: ['V', 'W', 'P'],
      correctAnswer: 'V',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/W.mp4',
      options: ['W', 'V', 'Z'],
      correctAnswer: 'W',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Alphabet/Z.mp4',
      options: ['Z', 'W', 'V'],
      correctAnswer: 'Z',
    ),

    // ── Animal ─────────────────────────────────────────────────
    Question(
      prompt: 'assets/guess_me/videos/Animal/bird.mp4',
      options: ['Bird', 'Fish', 'Dog'],
      correctAnswer: 'Bird',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Animal/dog.mp4',
      options: ['Dog', 'Pig', 'Horse'],
      correctAnswer: 'Dog',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Animal/fish.mp4',
      options: ['Fish', 'Bird', 'Monkey'],
      correctAnswer: 'Fish',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Animal/horse.mp4',
      options: ['Horse', 'Dog', 'Pig'],
      correctAnswer: 'Horse',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Animal/monkey.mp4',
      options: ['Monkey', 'Fish', 'Bird'],
      correctAnswer: 'Monkey',
    ),
    Question(
      prompt: 'assets/guess_me/videos/Animal/pig.mp4',
      options: ['Pig', 'Horse', 'Dog'],
      correctAnswer: 'Pig',
    ),
  ];

  return questions;
}

// ─────────────────────────────────────────────────────────────
//  THEME CONSTANTS
// ─────────────────────────────────────────────────────────────
const _kBlueLight = Color(0xFF27AAEB);
const _kBlueMid = Color(0xFF1E9EDB);
const _kBlueDark = Color(0xFF0D6FAB);
const _kGold = Color(0xFFFFD700);

// ═════════════════════════════════════════════════════════════
//  GAME SCREEN
// ═════════════════════════════════════════════════════════════
class GuessMeScreen extends StatefulWidget {
  final VoidCallback? onGameFinished;

  const GuessMeScreen({super.key, this.onGameFinished});

  @override
  State<GuessMeScreen> createState() => _GuessMeScreenState();
}

class _GuessMeScreenState extends State<GuessMeScreen>
    with TickerProviderStateMixin {
  late final List<Question> _questions;
  late final List<List<Question>> _rounds;

  int _lives = 3;
  int _score = 0;
  int _remainingSeconds = 15;
  int _roundIndex = 0;
  int _roundQuestionIndex = 0;
  String? _selectedAnswer;
  late List<Question> _currentRoundQuestions;
  String? _roundTransitionMessage;

  Timer? _countdownTimer;
  Timer? _roundTransitionTimer;

  late AnimationController _heartShakeCtrl;
  late AnimationController _scorePopCtrl;
  late Animation<double> _scorePopAnim;

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _questions = buildQuestionList()..shuffle(Random());
    _rounds = _buildRounds(_questions);
    _currentRoundQuestions = List<Question>.from(_rounds.first);
    _shuffleOptionsForCurrentQuestion();

    _heartShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scorePopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scorePopAnim = Tween<double>(begin: 1.0, end: 1.45).animate(
      CurvedAnimation(parent: _scorePopCtrl, curve: Curves.elasticOut),
    );

    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _roundTransitionTimer?.cancel();
    _heartShakeCtrl.dispose();
    _scorePopCtrl.dispose();
    super.dispose();
  }

  // ─── Timer ───────────────────────────────────────────────────
  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _remainingSeconds = 15;
          _applyLifeLoss(); // time's up → lose a life
        }
      });
    });
  }

  void _resetTimer() => setState(() => _remainingSeconds = 15);

  // ─── Helpers ─────────────────────────────────────────────────
  Question get _currentQ => _currentRoundQuestions[_roundQuestionIndex];
  bool get _isLastQuestion {
    final isLastRound = _roundIndex >= _rounds.length - 1;
    final isLastQuestionInRound =
        _roundQuestionIndex >= _currentRoundQuestions.length - 1;
    return isLastRound && isLastQuestionInRound;
  }

  String get _formattedTime {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  List<List<Question>> _buildRounds(List<Question> questions) {
    final rounds = <List<Question>>[];
    int start = 0;
    int roundNumber = 1;

    while (start < questions.length) {
      final roundSize = roundNumber == 1 ? 3 : 2 * roundNumber + 1;
      final end = (start + roundSize < questions.length)
          ? start + roundSize
          : questions.length;
      rounds.add(questions.sublist(start, end));
      start = end;
      roundNumber++;
    }

    return rounds;
  }

  void _shuffleOptionsForCurrentQuestion() {
    _currentRoundQuestions[_roundQuestionIndex].options.shuffle(Random());
  }

  void _showRoundTransitionMessage({required int completedRound}) {
    if (_roundIndex >= _rounds.length - 1) return;

    _roundTransitionTimer?.cancel();
    setState(() {
      _roundTransitionMessage =
          'Round $completedRound complete!\nStarting Round ${completedRound + 1}';
    });

    _roundTransitionTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _roundTransitionMessage = null);
    });
  }

  // ─── Answer handling ─────────────────────────────────────────
  void _onAnswerSelected(String answer) {
    if (_selectedAnswer != null) return; // guard double-tap

    final correct = answer == _currentQ.correctAnswer;
    setState(() => _selectedAnswer = answer);

    if (correct) {
      _score++;
      _scorePopCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 700), _advance);
    } else {
      _heartShakeCtrl.forward(from: 0);
      // FIX: was two identical branches controlled by a useless bool param.
      // Now one clean path: lose life, then advance.
      _applyLifeLoss();
    }
  }

  /// Deducts a life. Ends the game if none remain; otherwise advances
  /// to the next question after a short feedback delay.
  void _applyLifeLoss() {
    setState(() => _lives = (_lives - 1).clamp(0, 3));
    if (_lives <= 0) {
      _endGame(won: false);
    } else {
      Future.delayed(const Duration(milliseconds: 700), _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    if (_isLastQuestion) {
      _endGame(won: true);
      return;
    }

    setState(() {
      if (_roundQuestionIndex < _currentRoundQuestions.length - 1) {
        _roundQuestionIndex++;
      } else if (_roundIndex < _rounds.length - 1) {
        final completedRound = _roundIndex + 1;
        _roundIndex++;
        _roundQuestionIndex = 0;
        _currentRoundQuestions = List<Question>.from(_rounds[_roundIndex]);
        _showRoundTransitionMessage(completedRound: completedRound);
      } else {
        _endGame(won: true);
        return;
      }

      _selectedAnswer = null;
      _shuffleOptionsForCurrentQuestion();
      _resetTimer();
    });
  }

  // ─── End game ────────────────────────────────────────────────
  void _endGame({required bool won}) {
    _countdownTimer?.cancel();
    widget.onGameFinished?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: won
                ? WinScreen(score: _score, total: _questions.length)
                : DefeatScreen(
                    score: _score,
                    total: _questions.length,
                    questionIndex: _roundQuestionIndex),
          ),
        ),
      );
    });
  }

  // ─── Button state ────────────────────────────────────────────
  _ButtonState _stateOf(String option) {
    if (_selectedAnswer == null) return _ButtonState.idle;
    if (option == _currentQ.correctAnswer) return _ButtonState.correct;
    if (option == _selectedAnswer) return _ButtonState.wrong;
    return _ButtonState.dimmed;
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.guessMe,
        child: SafeArea(
          child: Stack(
            children: [
              const _StripedBackground(),
              Column(
                children: [
                  _buildAppBar(),
                  const SizedBox(height: 6),
                  _buildStatusRow(),
                  _buildProgressBar(),
                  const SizedBox(height: 12),
                  Expanded(flex: 3, child: _buildAnswerArea()),
                  Expanded(flex: 4, child: _buildQuestionCanvas()),
                ],
              ),
              if (_roundTransitionMessage != null)
                Positioned(
                  top: 150,
                  left: 24,
                  right: 24,
                  child: _buildRoundTransitionBanner(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppBackIconButton(
            onTap: () => Navigator.of(context).maybePop(),
            size: 44,
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _kBlueDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white30, width: 1.5),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
              ],
            ),
            child: const _LogoWidget(),
          ),
          // Same width as the back button so the logo stays centered.
          const SizedBox(width: 44, height: 44),
        ],
      ),
    );
  }

  // ─── Status row ──────────────────────────────────────────────
  Widget _buildStatusRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _heartShakeCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(sin(_heartShakeCtrl.value * pi * 6) * 7, 0),
              child: child,
            ),
            child: Row(
              children: List.generate(
                  3,
                  (i) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          i < _lives ? Icons.favorite : Icons.favorite_border,
                          color: i < _lives ? Colors.red : Colors.red.shade200,
                          size: 30,
                          shadows: const [
                            Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                      )),
            ),
          ),
          Expanded(
            child: Center(
              child: ScaleTransition(
                scale: _scorePopAnim,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(children: [
                    const TextSpan(
                      text: 'Score:\n',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.2),
                    ),
                    TextSpan(
                      text: '$_score',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          _TimerPill(
              formattedTime: _formattedTime, isWarning: _remainingSeconds <= 5),
        ],
      ),
    );
  }

  // ─── Progress bar ────────────────────────────────────────────
  Widget _buildProgressBar() {
    final progress = (_roundQuestionIndex + 1) / _currentRoundQuestions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Round ${_roundIndex + 1} • Question ${_roundQuestionIndex + 1} / ${_currentRoundQuestions.length}',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundTransitionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        _roundTransitionMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }

  // ─── Answer buttons ──────────────────────────────────────────
  Widget _buildAnswerArea() {
    final opts = _currentQ.options;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (opts.length >= 2)
            Row(children: [
              Expanded(
                  child: _AnswerButton(
                label: opts[0],
                state: _stateOf(opts[0]),
                onTap: () => _onAnswerSelected(opts[0]),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _AnswerButton(
                label: opts[1],
                state: _stateOf(opts[1]),
                onTap: () => _onAnswerSelected(opts[1]),
              )),
            ]),
          const SizedBox(height: 12),
          for (int i = 2; i < opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.55,
                child: _AnswerButton(
                  label: opts[i],
                  state: _stateOf(opts[i]),
                  onTap: () => _onAnswerSelected(opts[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Question canvas ─────────────────────────────────────────
  Widget _buildQuestionCanvas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _QuestionVideoPlayer(
            key: ValueKey('$_roundIndex-$_roundQuestionIndex'),
            prompt: _currentQ.prompt,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  ANIMATED QUESTION CANVAS
//  A polished animated placeholder until you have your videos.
//  Each prompt gets its own emoji + gradient + drifting particles.
// ═════════════════════════════════════════════════════════════

String _normalizePromptKey(String prompt) {
  final withoutExt = prompt.replaceAll(RegExp(r'\.(mp4|mov|avi)$'), '');
  final baseName = withoutExt.split('/').last.toLowerCase();
  return baseName
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

const _kPromptEmoji = {
  'happy_birthday': '🎂',
  'good_morning': '☀️',
  'congratulations': '🏆',
  'how_are_you': '🤔',
  'i_love_you': '❤️',
  'see_you_later': '👋',
  'thank_you': '🙏',
  'hello': '👋',
  'bye': '👋',
  'take_care': '💛',
  'good_luck': '🍀',
  'house': '🏠',
  'bridge': '🌉',
  'church': '⛪',
  'farm': '🚜',
  'ceiling': '🛏️',
  'door': '🚪',
  'floor': '🧱',
  'grass': '🌿',
  'park': '🌳',
  'moon': '🌙',
  'plant': '🌱',
  'mountain': '⛰️',
  'rain': '🌧️',
  'bathroom': '🛁',
  'bedroom': '🛏️',
  'kitchen': '🍽️',
  'living_room': '🛋️',
  'elevator': '🛗',
  'hospital': '🏥',
  'garden': '🌷',
  'beautiful': '✨',
  'ugly': '😬',
  'bald': '🧑',
  'clap': '👏',
  'building': '🏢',
  'cloud': '☁️',
  'fire': '🔥',
  'flower': '🌸',
  'gate': '🚪',
  'light': '💡',
  'pool': '🏊',
  'market': '🛍️',
};

const _kPromptGradients = {
  'happy_birthday': [Color(0xFFFFF9C4), Color(0xFFFFE0B2)],
  'good_morning': [Color(0xFFFFF3E0), Color(0xFFB3E5FC)],
  'congratulations': [Color(0xFFF3E5F5), Color(0xFFE8F5E9)],
  'how_are_you': [Color(0xFFE1F5FE), Color(0xFFB3E5FC)],
  'i_love_you': [Color(0xFFFFE4E4), Color(0xFFFFCDD2)],
  'see_you_later': [Color(0xFFFFF3E0), Color(0xFFFFE082)],
  'thank_you': [Color(0xFFE8F5E9), Color(0xFFB2DFDB)],
};

class _QuestionVideoPlayer extends StatefulWidget {
  final String prompt;
  const _QuestionVideoPlayer({super.key, required this.prompt});

  @override
  State<_QuestionVideoPlayer> createState() => _QuestionVideoPlayerState();
}

class _QuestionVideoPlayerState extends State<_QuestionVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  List<String> get _assetCandidates {
    if (!widget.prompt.startsWith('assets/guess_me/videos/')) return const [];
    final fileName = widget.prompt.split('/').last;
    const legacyRoot = 'lib/games/guesssme1/assets/videos';
    return {
      widget.prompt,
      '$legacyRoot/$fileName',
      '$legacyRoot/${fileName.toLowerCase()}',
      '$legacyRoot/${fileName.toUpperCase()}',
    }.toList();
  }

  bool get _hasVideoAsset => _assetCandidates.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasVideoAsset) _initializeFuture = _initializeController();
  }

  Future<void> _initializeController() async {
    VideoPlayerController? loadedController;
    Object? lastError;
    for (final assetPath in _assetCandidates) {
      final candidate = kIsWeb
          ? VideoPlayerController.networkUrl(
              Uri.parse('/assets/${Uri.encodeFull(assetPath)}'),
            )
          : VideoPlayerController.asset(assetPath);
      try {
        await candidate.initialize();
        loadedController = candidate;
        break;
      } catch (error) {
        lastError = error;
        await candidate.dispose();
      }
    }

    if (loadedController == null) {
      throw lastError ?? StateError('No video asset could be loaded.');
    }

    await loadedController.setLooping(false);
    await loadedController.setVolume(0);
    await loadedController.play();
    if (!mounted) {
      await loadedController.dispose();
      return;
    }
    _controller = loadedController;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant _QuestionVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prompt != widget.prompt) {
      final oldController = _controller;
      _controller = null;
      if (oldController != null) unawaited(oldController.dispose());
      _initializeFuture = _hasVideoAsset ? _initializeController() : null;
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasVideoAsset) return _AnimatedQuestionCanvas(prompt: widget.prompt);

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        final controller = _controller;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError ||
            controller == null ||
            !controller.value.isInitialized) {
          return _AnimatedQuestionCanvas(prompt: widget.prompt);
        }
        return VideoPlayerWithControls(
          controller: controller,
          belowControls: const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Watch and guess the word!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Particle configs: [leftFraction, topFraction, fontSize, phaseOffset]
const _kParticles = [
  [0.10, 0.12, 26.0, 0.00],
  [0.78, 0.08, 20.0, 0.33],
  [0.82, 0.68, 18.0, 0.67],
  [0.06, 0.74, 22.0, 0.50],
  [0.52, 0.82, 19.0, 0.20],
];

class _AnimatedQuestionCanvas extends StatefulWidget {
  final String prompt;
  const _AnimatedQuestionCanvas({required this.prompt});

  @override
  State<_AnimatedQuestionCanvas> createState() =>
      _AnimatedQuestionCanvasState();
}

class _AnimatedQuestionCanvasState extends State<_AnimatedQuestionCanvas>
    with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _particleCtrl;

  late Animation<double> _bounceY;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _bounceY = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promptKey = _normalizePromptKey(widget.prompt);
    final emoji = _kPromptEmoji[promptKey] ?? '🤔';
    final colors = _kPromptGradients[promptKey] ??
        [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      // LayoutBuilder gives us the real canvas size for particle offsets.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Drifting background particles ──────────────
              ..._kParticles.map((c) {
                final lf = c[0];
                final tf = c[1];
                final fs = c[2];
                final ph = c[3];

                return AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (_, __) {
                    final t = (_particleCtrl.value + ph) % 1.0;
                    final dy = sin(t * pi * 2) * 12;
                    final dx = cos(t * pi * 2) * 6;
                    return Positioned(
                      left: lf * w + dx,
                      top: tf * h + dy,
                      child: Opacity(
                        opacity: 0.20,
                        child: Text(emoji, style: TextStyle(fontSize: fs)),
                      ),
                    );
                  },
                );
              }),

              // ── Main bouncing emoji ─────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_bounceCtrl, _pulseCtrl]),
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _bounceY.value),
                    child: Transform.scale(
                      scale: _scale.value,
                      child: Text(emoji, style: const TextStyle(fontSize: 88)),
                    ),
                  ),
                ),
              ),

              // ── Bottom label ────────────────────────────────
              Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline_rounded,
                            size: 14, color: _kBlueDark),
                        SizedBox(width: 5),
                        Text(
                          'Watch and guess the phrase!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kBlueDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── "Video coming soon" badge ───────────────────
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kBlueDark.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '▶  Video coming soon',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  WIN SCREEN
// ═════════════════════════════════════════════════════════════
class WinScreen extends StatefulWidget {
  final int score;
  final int total;
  const WinScreen({super.key, required this.score, required this.total});

  @override
  State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen> with TickerProviderStateMixin {
  late AnimationController _starCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _starSpin;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _starCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _starSpin = Tween<double>(begin: 0, end: 1).animate(_starCtrl);

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
            CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));
    _contentCtrl.forward();
  }

  @override
  void dispose() {
    _starCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.score / widget.total * 100).round();
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A4F82), Color(0xFF1478B5), Color(0xFF1E9EDB)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: FadeTransition(
            opacity: _contentFade,
            child: SlideTransition(
              position: _contentSlide,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RotationTransition(
                        turns: _starSpin,
                        child: const Icon(
                          Icons.star_rounded,
                          size: 90,
                          color: _kGold,
                          shadows: [
                            Shadow(
                                color: Colors.black26,
                                blurRadius: 16,
                                offset: Offset(0, 4))
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'YOU WIN!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                                color: Colors.black38,
                                blurRadius: 10,
                                offset: Offset(0, 4))
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Congratulations! You made it through all the questions!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      _WinScoreCard(
                          score: widget.score, total: widget.total, pct: pct),
                      const SizedBox(height: 36),
                      _BigButton(
                        label: 'Play Again',
                        icon: Icons.replay_rounded,
                        color: _kGold,
                        textColor: Colors.black87,
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const GuessMeScreen()),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Exit',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WinScoreCard extends StatelessWidget {
  final int score, total, pct;
  const _WinScoreCard(
      {required this.score, required this.total, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white30, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
              label: 'Score',
              value: '$score / $total',
              icon: Icons.star_rounded,
              color: _kGold),
          Container(width: 1, height: 48, color: Colors.white24),
          _StatChip(
              label: 'Accuracy',
              value: '$pct%',
              icon: Icons.track_changes_rounded,
              color: Colors.greenAccent),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  DEFEAT SCREEN
// ═════════════════════════════════════════════════════════════
class DefeatScreen extends StatefulWidget {
  final int score;
  final int total;
  final int questionIndex;
  const DefeatScreen(
      {super.key,
      required this.score,
      required this.total,
      required this.questionIndex});

  @override
  State<DefeatScreen> createState() => _DefeatScreenState();
}

class _DefeatScreenState extends State<DefeatScreen>
    with TickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _iconBounce;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _iconBounce = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));

    _contentCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _shakeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0A0A), Color(0xFF5C1A1A), Color(0xFFAB2E2E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: FadeTransition(
            opacity: _contentFade,
            child: SlideTransition(
              position: _contentSlide,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _iconBounce,
                        child: const Icon(
                          Icons.heart_broken_rounded,
                          size: 100,
                          color: Colors.red,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                blurRadius: 16,
                                offset: Offset(0, 6))
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'LOSE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, 4))
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You ran out of lives. Better luck next time!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 15),
                      ),
                      const SizedBox(height: 32),
                      _DefeatScoreCard(
                          score: widget.score,
                          questionIndex: widget.questionIndex),
                      const SizedBox(height: 36),
                      _BigButton(
                        label: 'Try Again',
                        icon: Icons.refresh_rounded,
                        color: Colors.red.shade700,
                        textColor: Colors.white,
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const GuessMeScreen()),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Exit',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefeatScoreCard extends StatelessWidget {
  final int score, questionIndex;
  const _DefeatScoreCard({required this.score, required this.questionIndex});

  @override
  Widget build(BuildContext context) {
    final questionsFaced = questionIndex + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
              label: 'Faced',
              value: '$questionsFaced',
              icon: Icons.videocam_outlined,
              color: Colors.blueAccent),
          Container(width: 1, height: 48, color: Colors.white12),
          _StatChip(
              label: 'Correct',
              value: '$score',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.greenAccent),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatChip(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
        ],
      );
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, textColor;
  final VoidCallback onTap;
  const _BigButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.textColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════
//  STRIPED BACKGROUND
// ═════════════════════════════════════════════════════════════
class _StripedBackground extends StatelessWidget {
  const _StripedBackground();
  @override
  Widget build(BuildContext context) =>
      SizedBox.expand(child: CustomPaint(painter: _StripePainter()));
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kBlueMid);
    final p = Paint()..color = _kBlueLight;
    const sw = 44.0;
    for (double x = 0; x < size.width; x += sw * 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, sw, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ═════════════════════════════════════════════════════════════
//  LOGO WIDGET
// ═════════════════════════════════════════════════════════════
class _LogoWidget extends StatelessWidget {
  const _LogoWidget();
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/images/guess_me_icon.png',
          fit: BoxFit.cover,
          // If the asset can't be found, fall back to the old text logo.
          errorBuilder: (_, __, ___) => Container(
            color: _kBlueDark,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('GUESS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                  Text('ME?',
                      style: TextStyle(
                          color: _kGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════
//  TIMER PILL
// ═════════════════════════════════════════════════════════════
class _TimerPill extends StatelessWidget {
  final String formattedTime;
  final bool isWarning;
  const _TimerPill({required this.formattedTime, required this.isWarning});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isWarning ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
              color: isWarning ? Colors.red : Colors.transparent, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        child: Text(
          'TIME: $formattedTime',
          style: TextStyle(
            color: isWarning ? Colors.red : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════
//  ANSWER BUTTON
// ═════════════════════════════════════════════════════════════
enum _ButtonState { idle, correct, wrong, dimmed }

class _AnswerButton extends StatefulWidget {
  final String label;
  final _ButtonState state;
  final VoidCallback onTap;
  const _AnswerButton(
      {required this.label, required this.state, required this.onTap});

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Color get _bg => switch (widget.state) {
        _ButtonState.correct => const Color(0xFFD4EDDA),
        _ButtonState.wrong => const Color(0xFFF8D7DA),
        _ButtonState.dimmed => Colors.white.withValues(alpha: 0.45),
        _ButtonState.idle => Colors.white,
      };

  Color get _border => switch (widget.state) {
        _ButtonState.correct => Colors.green.shade600,
        _ButtonState.wrong => Colors.red.shade600,
        _ButtonState.dimmed => const Color(0xFF1565C0),
        _ButtonState.idle => const Color(0xFF1565C0),
      };

  IconData? get _icon => switch (widget.state) {
        _ButtonState.correct => Icons.check_circle_outline_rounded,
        _ButtonState.wrong => Icons.cancel_outlined,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.state == _ButtonState.idle) _press.reverse();
      },
      onTapUp: (_) {
        _press.forward();
        widget.onTap();
      },
      onTapCancel: () => _press.forward(),
      child: ScaleTransition(
        scale: _press,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: _border.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: widget.state == _ButtonState.dimmed
                        ? Colors.black38
                        : Colors.black87,
                  ),
                ),
              ),
              if (_icon != null) ...[
                const SizedBox(width: 6),
                Icon(_icon,
                    size: 18,
                    color: widget.state == _ButtonState.correct
                        ? Colors.green.shade700
                        : Colors.red.shade700),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
