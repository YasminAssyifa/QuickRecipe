import json
import unittest

import baseline
import train
from features import features, normalize


class NormalizeTests(unittest.TestCase):
    def test_slang_case_and_punctuation(self):
        self.assertEqual(normalize('GAK ADA TELOR, gantinya apa???'),
                         ['tidak', 'ada', 'telur', 'gantinya', 'apa'])

    def test_reduplication_numbers_and_fillers(self):
        self.assertEqual(normalize('pengen yg manis2 dong'), ['ingin', 'yang', 'manis'])
        self.assertEqual(normalize('resep 15 mnt'), ['resep', '0', 'menit'])

    def test_features_cover_words_pairs_and_characters(self):
        result = features(['tidak', 'ada'])
        for expected in ['w:tidak', 'b:tidak ada', 'c: ti', 'c:dak ', 'c: ada ']:
            self.assertIn(expected, result)


class BaselineTests(unittest.TestCase):
    def test_rules(self):
        self.assertEqual(baseline.predict('santan bisa diganti apa'), 'substitusi_bahan')
        self.assertEqual(baseline.predict('isi kulkasku bisa jadi apa'), 'pakai_kulkas')
        self.assertEqual(baseline.predict('cuaca besok'), 'di_luar_topik')


class DataTests(unittest.TestCase):
    def test_test_set_does_not_leak_into_training(self):
        seen = set()
        for path in train.TRAIN_FILES:
            seen.update(' '.join(normalize(text)) for text in train.load(path)[0])
        leaked = [text for text in train.load(train.TEST_FILE)[0] if ' '.join(normalize(text)) in seen]
        self.assertEqual(leaked, [], 'Test questions must not appear in the training data.')

    def test_every_intent_has_training_examples(self):
        labels = []
        for path in train.TRAIN_FILES:
            labels += train.load(path)[1]
        for intent in train.INTENTS:
            self.assertGreaterEqual(labels.count(intent), 20, intent)


class ExportTests(unittest.TestCase):
    def test_exported_model_matches_parity_fixture(self):
        exported = json.loads(train.MODEL_OUT.read_text(encoding='utf-8'))
        fixture = json.loads(train.PARITY_OUT.read_text(encoding='utf-8'))
        self.assertEqual(exported['classes'], fixture['classes'])
        for case in fixture['cases']:
            actual = train.predict_exported(exported, case['text'])
            for a, b in zip(actual, case['probabilities']):
                self.assertAlmostEqual(a, b, places=6)


if __name__ == '__main__':
    unittest.main()
