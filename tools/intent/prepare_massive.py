"""Build data/massive_oos.csv from the Indonesian MASSIVE file.

Source: MASSIVE 1.1 (Amazon, CC BY 4.0), file 1.1/data/id-ID.jsonl from
https://amazon-massive-nlu-dataset.s3.amazonaws.com/amazon-massive-dataset-1.1.tar.gz
Only the train partition is used. The cooking scenario is skipped because
those questions belong to the recipe intents, not to "di_luar_topik".
Greetings are skipped because the app answers them with the "bantuan"
intent.
"""
import csv
import json
import random
import sys
from pathlib import Path

PER_SCENARIO = 14
SEED = 7
SKIPPED_SCENARIOS = {'cooking'}
SKIPPED_INTENTS = {'general_greet'}
SMALL_TALK = ('apa kabar', 'harimu')
WAKE_WORDS = {'olly'}
OUTPUT = Path(__file__).parent / 'data' / 'massive_oos.csv'


def clean(utterance):
    words = [word for word in utterance.split() if word.lower() not in WAKE_WORDS]
    return ' '.join(words).strip()


def sample(rows, per_scenario=PER_SCENARIO, seed=SEED):
    by_scenario = {}
    for row in rows:
        if (row['partition'] != 'train' or row['scenario'] in SKIPPED_SCENARIOS
                or row['intent'] in SKIPPED_INTENTS):
            continue
        text = clean(row['utt'])
        if text and not any(phrase in text for phrase in SMALL_TALK):
            by_scenario.setdefault(row['scenario'], set()).add(text)
    rng = random.Random(seed)
    picked = []
    for scenario in sorted(by_scenario):
        texts = sorted(by_scenario[scenario])
        picked += rng.sample(texts, min(per_scenario, len(texts)))
    return picked


def main(path):
    with open(path, encoding='utf-8') as handle:
        rows = [json.loads(line) for line in handle if line.strip()]
    texts = sample(rows)
    with open(OUTPUT, 'w', encoding='utf-8', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerow(['text', 'intent', 'source'])
        for text in texts:
            writer.writerow([text, 'di_luar_topik', 'massive'])
    print(f'Wrote {len(texts)} rows to {OUTPUT}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('python prepare_massive.py <id-ID.jsonl>')
    main(sys.argv[1])
