import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_recipe/additions/intent_classifier.dart';

void main() {
  final classifier = IntentClassifier.parse(
    File('assets/ai/intent_model.json').readAsStringSync(),
  );

  test('Dart returns the same probabilities as the Python trainer', () {
    final fixture = jsonDecode(
      File('test/fixtures/intent_parity.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(classifier.classes, fixture['classes']);
    for (final item in fixture['cases'] as List) {
      final expected = List<num>.from(item['probabilities'] as List);
      final actual = classifier.probabilities(item['text'] as String);
      for (var i = 0; i < expected.length; i++) {
        expect(
          actual[i],
          closeTo(expected[i], 1e-6),
          reason: '"${item['text']}" ${classifier.classes[i]}',
        );
      }
    }
  });

  test('Normalisation matches the Python rules', () {
    expect(classifier.normalize('GAK ADA TELOR, gantinya apa???'), [
      'tidak',
      'ada',
      'telur',
      'gantinya',
      'apa',
    ]);
    expect(classifier.normalize('pengen yg manis2 dong'), [
      'ingin',
      'yang',
      'manis',
    ]);
    expect(classifier.normalize('resep 15 mnt'), ['resep', '0', 'menit']);
    expect(classifier.normalize('resep 15 mnt', keepNumbers: true), [
      'resep',
      '15',
      'menit',
    ]);
  });

  test('Built-in prompts are recognised with confidence', () {
    const expected = {
      'Suggest an easy meal I can cook in under 30 minutes.': 'cari_resep',
      'What can I cook with the ingredients in my fridge?': 'pakai_kulkas',
      'Suggest a recipe with only a few ingredients.': 'cari_resep',
      'Suggest a low-calorie meal under 400 calories.': 'cari_resep',
      'What can I cook with eggs?': 'cari_resep',
      'Suggest a quick dinner': 'cari_resep',
      'How can I replace milk?': 'substitusi_bahan',
    };
    expected.forEach((text, intent) {
      final prediction = classifier.predict(text);
      expect(prediction.intent, intent, reason: text);
      expect(prediction.confident, isTrue, reason: text);
    });
  });
}
