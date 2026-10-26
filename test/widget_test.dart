import 'package:flutter_test/flutter_test.dart';
import 'package:sign_language_app/classifiers/sign_classifier.dart';

void main() {
  group('SignClassifier', () {
    test('returns null for incomplete alphabet landmarks', () {
      final classifier = SignClassifier();

      expect(classifier.classifyAlphabet(const []), isNull);
    });

    test('returns null for incomplete number landmarks', () {
      final classifier = SignClassifier();

      expect(classifier.classifyNumber(const []), isNull);
    });

    test('returns null for incomplete word landmarks', () {
      final classifier = SignClassifier();

      expect(classifier.classifyWords(const []), isNull);
    });
  });
}
