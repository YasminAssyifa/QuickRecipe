"""Train, evaluate and export the intent model.

Steps:
1. Load data/train.csv and data/massive_oos.csv (training data) and
   data/test.csv (held-out data written by the team).
2. Five-fold stratified cross-validation on the training data to pick the
   regularisation strength C and the confidence threshold, and to compare
   the model with the keyword baseline.
3. Fit the final model on all training data and evaluate it once on the
   held-out test data when it has rows.
4. Export assets/ai/intent_model.json for the app,
   test/fixtures/intent_parity.json for the Dart parity test, and
   report.md with the results.
"""
import csv
import json
import math
from collections import Counter
from pathlib import Path

import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score, precision_recall_fscore_support
from sklearn.model_selection import StratifiedKFold

import baseline
from features import CHAR_NGRAMS, SLANG, analyze, features, normalize

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
TRAIN_FILES = [HERE / 'data' / 'train.csv', HERE / 'data' / 'massive_oos.csv']
TEST_FILE = HERE / 'data' / 'test.csv'
MODEL_OUT = ROOT / 'assets' / 'ai' / 'intent_model.json'
PARITY_OUT = ROOT / 'test' / 'fixtures' / 'intent_parity.json'
REPORT_OUT = HERE / 'report.md'

INTENTS = ['cari_resep', 'pakai_kulkas', 'info_resep', 'substitusi_bahan', 'bantuan', 'di_luar_topik']
REJECTED = 'di_luar_topik'
C_GRID = [1, 3, 10, 30, 100]
TOLERANCE = 0.01
THRESHOLDS = [round(0.25 + 0.05 * step, 2) for step in range(10)]
FOLDS = 5
SEED = 7
PARITY_TEXTS = [
    'masak apa pakai telur?', 'Suggest a quick dinner', 'How can I replace milk?',
    'What can I cook with eggs?', 'santan bisa diganti apa', 'isi kulkasku bisa jadi apa',
    'nasi goreng telur berapa kalori', 'halo', 'cuaca besok gimana', 'resep yg 15 mnt',
    'pengen yg manis2', 'Suggest an easy meal I can cook in under 30 minutes.',
    'What can I cook with the ingredients in my fridge?',
    'Suggest a recipe with only a few ingredients.', 'Suggest a low-calorie meal under 400 calories.',
    'GAK ADA TELOR, gantinya apa???', 'kucing', '', '!!!', 'résumé café 123',
]


def load(path):
    texts, labels, sources, seen = [], [], [], set()
    with open(path, encoding='utf-8', newline='') as handle:
        for line, row in enumerate(csv.DictReader(handle), start=2):
            text = (row.get('text') or '').strip()
            if not text:
                continue
            intent = (row.get('intent') or '').strip()
            if intent not in INTENTS:
                raise SystemExit(f'{path.name}:{line}: unknown intent "{intent}"')
            key = ' '.join(normalize(text))
            if key in seen:
                continue
            seen.add(key)
            texts.append(text)
            labels.append(intent)
            sources.append((row.get('source') or 'team').strip())
    return texts, labels, sources


def build(c_value):
    vectorizer = TfidfVectorizer(analyzer=analyze, sublinear_tf=True, min_df=2)
    model = LogisticRegression(C=c_value, max_iter=5000, class_weight='balanced')
    return vectorizer, model


def fit(texts, labels, c_value):
    vectorizer, model = build(c_value)
    model.fit(vectorizer.fit_transform(texts), labels)
    return vectorizer, model


def out_of_fold(texts, labels, c_value):
    probabilities = np.zeros((len(texts), len(INTENTS)))
    folds = StratifiedKFold(n_splits=FOLDS, shuffle=True, random_state=SEED)
    for train_index, test_index in folds.split(texts, labels):
        vectorizer, model = fit([texts[i] for i in train_index], [labels[i] for i in train_index], c_value)
        fold = model.predict_proba(vectorizer.transform([texts[i] for i in test_index]))
        order = [list(model.classes_).index(intent) for intent in INTENTS]
        probabilities[test_index] = fold[:, order]
    return probabilities


def decide(probabilities, threshold):
    return [INTENTS[int(row.argmax())] if row.max() >= threshold else REJECTED for row in probabilities]


def macro_f1(labels, predicted):
    return f1_score(labels, predicted, labels=INTENTS, average='macro', zero_division=0)


def export(vectorizer, model, threshold, stats):
    order = [list(model.classes_).index(intent) for intent in INTENTS]
    names = vectorizer.get_feature_names_out().tolist()
    return {
        'version': 1,
        'classes': INTENTS,
        'threshold': threshold,
        'charNgrams': list(CHAR_NGRAMS),
        'slang': SLANG,
        'features': names,
        'idf': [round(float(value), 6) for value in vectorizer.idf_],
        'coef': [[round(float(value), 6) for value in model.coef_[row]] for row in order],
        'intercept': [round(float(model.intercept_[row]), 6) for row in order],
        'trainingStats': stats,
    }


def predict_exported(exported, text):
    """Reference inference over the exported JSON, mirrored by the Dart code."""
    index = {name: position for position, name in enumerate(exported['features'])}
    tokens = normalize(text, exported['slang'])
    counts = Counter(index[name] for name in features(tokens, tuple(exported['charNgrams'])) if name in index)
    vector = {position: (1 + math.log(count)) * exported['idf'][position] for position, count in counts.items()}
    norm = math.sqrt(sum(value * value for value in vector.values()))
    if norm > 0:
        vector = {position: value / norm for position, value in vector.items()}
    scores = [bias + sum(weights[position] * value for position, value in vector.items())
              for weights, bias in zip(exported['coef'], exported['intercept'])]
    top = max(scores)
    exps = [math.exp(score - top) for score in scores]
    total = sum(exps)
    return [value / total for value in exps]


def table(labels, predicted):
    precision, recall, f1, support = precision_recall_fscore_support(
        labels, predicted, labels=INTENTS, zero_division=0)
    lines = ['| Intent | Precision | Recall | F1 | Jumlah |', '|---|---|---|---|---|']
    for i, intent in enumerate(INTENTS):
        lines.append(f'| `{intent}` | {precision[i]:.2f} | {recall[i]:.2f} | {f1[i]:.2f} | {support[i]} |')
    return '\n'.join(lines)


def matrix(labels, predicted):
    values = confusion_matrix(labels, predicted, labels=INTENTS)
    short = ['cari', 'kulkas', 'info', 'subst', 'bantuan', 'luar']
    lines = ['| Asli \\ Tebakan | ' + ' | '.join(short) + ' |', '|---' * (len(short) + 1) + '|']
    for i, intent in enumerate(INTENTS):
        lines.append(f'| `{intent}` | ' + ' | '.join(str(v) for v in values[i]) + ' |')
    return '\n'.join(lines)


def summary(name, labels, predicted):
    return f'| {name} | {accuracy_score(labels, predicted):.3f} | {macro_f1(labels, predicted):.3f} |'


def main():
    texts, labels, sources = [], [], []
    for path in TRAIN_FILES:
        part = load(path)
        texts += part[0]
        labels += part[1]
        sources += part[2]
    test_texts, test_labels, _ = load(TEST_FILE)

    search = {}
    for c_value in C_GRID:
        probabilities = out_of_fold(texts, labels, c_value)
        search[c_value] = (macro_f1(labels, decide(probabilities, 0)), probabilities)
        print(f'C={c_value}: cross-validated macro F1 {search[c_value][0]:.3f}')
    # Prefer the strongest regularisation that is within TOLERANCE of the best
    # score: on small data a tiny gain from a weaker penalty is usually noise.
    top_score = max(score for score, _ in search.values())
    best_c = min(value for value in C_GRID if search[value][0] >= top_score - TOLERANCE)
    probabilities = search[best_c][1]
    threshold = max(THRESHOLDS, key=lambda t: (round(macro_f1(labels, decide(probabilities, t)), 3), -t))
    cv_model = decide(probabilities, threshold)
    cv_baseline = [baseline.predict(text) for text in texts]
    print(f'Chosen C={best_c}, threshold={threshold}')
    print(f'Model    accuracy {accuracy_score(labels, cv_model):.3f} macro F1 {macro_f1(labels, cv_model):.3f}')
    print(f'Baseline accuracy {accuracy_score(labels, cv_baseline):.3f} macro F1 {macro_f1(labels, cv_baseline):.3f}')

    vectorizer, model = fit(texts, labels, best_c)
    stats = {
        'examples': len(texts),
        'perIntent': dict(Counter(labels)),
        'perSource': dict(Counter(sources)),
        'c': best_c,
        'crossValidatedMacroF1': round(macro_f1(labels, cv_model), 4),
        'baselineMacroF1': round(macro_f1(labels, cv_baseline), 4),
    }
    exported = export(vectorizer, model, threshold, stats)

    reference = model.predict_proba(vectorizer.transform(PARITY_TEXTS))
    order = [list(model.classes_).index(intent) for intent in INTENTS]
    parity = []
    for row, text in enumerate(PARITY_TEXTS):
        expected = predict_exported(exported, text)
        drift = max(abs(a - b) for a, b in zip(expected, reference[row, order]))
        if drift > 1e-4:
            raise SystemExit(f'Exported model drifts from scikit-learn on "{text}": {drift}')
        parity.append({'text': text, 'probabilities': [round(value, 8) for value in expected]})

    MODEL_OUT.parent.mkdir(parents=True, exist_ok=True)
    MODEL_OUT.write_text(json.dumps(exported, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    PARITY_OUT.parent.mkdir(parents=True, exist_ok=True)
    PARITY_OUT.write_text(json.dumps({'classes': INTENTS, 'cases': parity}, ensure_ascii=False, indent=1),
                          encoding='utf-8')

    report = [
        '# Hasil latih model intent', '',
        '## Data', '',
        f'- Data latih: {len(texts)} kalimat (setelah duplikat dibuang).',
        '- Per sumber: ' + ', '.join(f'{k} {v}' for k, v in sorted(Counter(sources).items())) + '.',
        '- Per intent: ' + ', '.join(f'`{k}` {Counter(labels)[k]}' for k in INTENTS) + '.',
        f'- Data uji (ditulis tim, tidak dipakai saat latih): {len(test_texts)} kalimat.', '',
        '## Model', '',
        '- Fitur: kata, pasangan kata, dan potongan 3-5 huruf per kata, dibobot TF-IDF.',
        '- Algoritma: Logistic Regression (multinomial, `class_weight=balanced`).',
        f'- C terpilih: {best_c} (dari {C_GRID}; C terkecil yang skornya paling jauh {TOLERANCE} di bawah skor terbaik).',
        f'- Ambang keyakinan: {threshold}. Di bawah ambang, aplikasi meminta pengguna memperjelas pertanyaan.',
        f'- Jumlah fitur: {len(exported["features"])}.', '',
        f'## Validasi silang {FOLDS}-fold (data latih)', '',
        'Prediksi di bawah ambang dihitung sebagai `di_luar_topik`.', '',
        '| Metode | Akurasi | Macro F1 |', '|---|---|---|',
        summary('Model', labels, cv_model), summary('Baseline kata kunci', labels, cv_baseline), '',
        '### Model per intent', '', table(labels, cv_model), '',
        '### Baseline per intent', '', table(labels, cv_baseline), '',
        '### Confusion matrix model', '', matrix(labels, cv_model), '',
        'Catatan: data latih memuat banyak kalimat yang mirip satu sama lain, jadi angka validasi silang',
        'cenderung lebih tinggi daripada pemakaian nyata. Angka yang jujur adalah hasil data uji di bawah.', '',
        '## Data uji', '',
    ]
    if test_texts:
        test_model = decide(
            np.array([predict_exported(exported, text) for text in test_texts]), threshold)
        test_baseline = [baseline.predict(text) for text in test_texts]
        report += ['| Metode | Akurasi | Macro F1 |', '|---|---|---|',
                   summary('Model', test_labels, test_model),
                   summary('Baseline kata kunci', test_labels, test_baseline), '',
                   '### Model per intent', '', table(test_labels, test_model), '',
                   '### Confusion matrix model', '', matrix(test_labels, test_model), '']
        print(f'Test     accuracy {accuracy_score(test_labels, test_model):.3f} '
              f'macro F1 {macro_f1(test_labels, test_model):.3f}')
    else:
        report += ['Belum ada data uji.', '']
    REPORT_OUT.write_text('\n'.join(report), encoding='utf-8')
    print(f'Wrote {MODEL_OUT.relative_to(ROOT)}, {PARITY_OUT.relative_to(ROOT)} and {REPORT_OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
