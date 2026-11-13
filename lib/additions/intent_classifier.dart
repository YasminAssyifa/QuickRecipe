import 'dart:convert';
import 'dart:math' as math;

/// Runs the intent model trained by tools/intent/train.py.
///
/// The text normalisation and features below must match
/// tools/intent/features.py exactly. test/intent_classifier_test.dart checks
/// that both sides return the same probabilities.
class IntentClassifier {
  IntentClassifier._(
    this.classes,
    this.threshold,
    this.slang,
    this.charNgrams,
    this._index,
    this._idf,
    this._coef,
    this._intercept,
  );

  factory IntentClassifier.fromJson(Map<String, dynamic> json) {
    final features = List<String>.from(json['features'] as List);
    List<double> numbers(Object? values) =>
        (values as List).map((value) => (value as num).toDouble()).toList();
    final ngrams = List<int>.from(json['charNgrams'] as List);
    return IntentClassifier._(
      List<String>.from(json['classes'] as List),
      (json['threshold'] as num).toDouble(),
      Map<String, String>.from(json['slang'] as Map),
      (ngrams[0], ngrams[1]),
      {for (var i = 0; i < features.length; i++) features[i]: i},
      numbers(json['idf']),
      (json['coef'] as List).map(numbers).toList(),
      numbers(json['intercept']),
    );
  }

  factory IntentClassifier.parse(String source) =>
      IntentClassifier.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final List<String> classes;
  final double threshold;
  final Map<String, String> slang;
  final (int, int) charNgrams;
  final Map<String, int> _index;
  final List<double> _idf;
  final List<List<double>> _coef;
  final List<double> _intercept;

  static final _nonAlphanumeric = RegExp(r'[^a-z0-9]+');
  static final _reduplicated = RegExp(r'^([a-z]+)2$');
  static final _number = RegExp(r'^[0-9]+$');

  /// Lower-cases, removes punctuation, replaces slang and numbers.
  /// Set [keepNumbers] to read amounts such as "15 menit".
  List<String> normalize(String text, {bool keepNumbers = false}) {
    final tokens = <String>[];
    for (var token
        in text.toLowerCase().replaceAll(_nonAlphanumeric, ' ').split(' ')) {
      if (token.isEmpty) continue;
      final reduplicated = _reduplicated.firstMatch(token);
      if (reduplicated != null) token = reduplicated.group(1)!;
      if (!keepNumbers && _number.hasMatch(token)) token = '0';
      token = slang[token] ?? token;
      if (token.isNotEmpty) tokens.add(token);
    }
    return tokens;
  }

  List<String> features(List<String> tokens) {
    final result = [for (final token in tokens) 'w:$token'];
    for (var i = 0; i + 1 < tokens.length; i++) {
      result.add('b:${tokens[i]} ${tokens[i + 1]}');
    }
    final (low, high) = charNgrams;
    for (final token in tokens) {
      final padded = ' $token ';
      for (var size = low; size <= high; size++) {
        for (var start = 0; start + size <= padded.length; start++) {
          result.add('c:${padded.substring(start, start + size)}');
        }
      }
    }
    return result;
  }

  /// Probability per class, in the order of [classes].
  List<double> probabilities(String text) {
    final counts = <int, int>{};
    for (final feature in features(normalize(text))) {
      final position = _index[feature];
      if (position != null) counts[position] = (counts[position] ?? 0) + 1;
    }
    final vector = {
      for (final entry in counts.entries)
        entry.key: (1 + math.log(entry.value)) * _idf[entry.key],
    };
    final norm = math.sqrt(
      vector.values.fold<double>(0, (sum, value) => sum + value * value),
    );
    if (norm > 0) vector.updateAll((_, value) => value / norm);
    final scores = [
      for (var row = 0; row < classes.length; row++)
        vector.entries.fold<double>(
          _intercept[row],
          (sum, entry) => sum + _coef[row][entry.key] * entry.value,
        ),
    ];
    final top = scores.reduce(math.max);
    final exps = scores.map((score) => math.exp(score - top)).toList();
    final total = exps.reduce((a, b) => a + b);
    return exps.map((value) => value / total).toList();
  }

  IntentPrediction predict(String text) {
    final values = probabilities(text);
    var best = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return IntentPrediction(
      intent: classes[best],
      confidence: values[best],
      confident: values[best] >= threshold,
    );
  }
}

class IntentPrediction {
  const IntentPrediction({
    required this.intent,
    required this.confidence,
    required this.confident,
  });
  final String intent;
  final double confidence;
  final bool confident;
}
