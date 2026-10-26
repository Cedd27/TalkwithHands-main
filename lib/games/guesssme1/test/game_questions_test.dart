import 'package:flutter_test/flutter_test.dart';
import 'package:guesssme1/main.dart';

void main() {
  test('buildQuestionList includes every available video asset', () {
    final questions = buildQuestionList();

    expect(questions.length, 73);
    expect(questions.every((q) => q.prompt.isNotEmpty), isTrue);
    expect(questions.every((q) => q.options.isNotEmpty), isTrue);
  });

  test('buildQuestionList includes more than the original three videos', () {
    final questions = buildQuestionList();

    expect(questions.length, greaterThan(3));
    expect(questions.every((q) => q.prompt.isNotEmpty), isTrue);
    expect(questions.every((q) => q.options.isNotEmpty), isTrue);
  });
}
