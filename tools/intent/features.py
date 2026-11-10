"""Text normalisation and feature extraction for the intent model.

The Dart side (lib/additions/intent_classifier.dart) repeats these exact
steps. The slang table is exported inside the model file so both sides
always use the same values, and the parity test checks that both return
the same probabilities.
"""
import re

CHAR_NGRAMS = (3, 5)

SLANG = {
    'gak': 'tidak', 'ga': 'tidak', 'gk': 'tidak', 'nggak': 'tidak', 'ngga': 'tidak',
    'enggak': 'tidak', 'engga': 'tidak', 'tdk': 'tidak', 'tak': 'tidak',
    'yg': 'yang', 'dgn': 'dengan', 'sm': 'sama', 'utk': 'untuk',
    'pake': 'pakai', 'pk': 'pakai', 'pke': 'pakai',
    'klo': 'kalau', 'kalo': 'kalau', 'kl': 'kalau',
    'gmn': 'bagaimana', 'gimana': 'bagaimana', 'gmana': 'bagaimana',
    'aja': 'saja', 'aj': 'saja', 'udh': 'sudah', 'udah': 'sudah', 'dah': 'sudah',
    'bs': 'bisa', 'bsa': 'bisa', 'mw': 'mau', 'pengen': 'ingin', 'pgn': 'ingin',
    'gw': 'aku', 'gue': 'aku', 'aq': 'aku', 'sy': 'saya',
    'dr': 'dari', 'brp': 'berapa', 'mnt': 'menit', 'rsp': 'resep',
    'cpt': 'cepat', 'cepet': 'cepat', 'bikin': 'buat', 'bkn': 'buat',
    'telor': 'telur', 'cabe': 'cabai', 'cemilan': 'camilan',
    'kulkasku': 'kulkas', 'dong': '', 'deh': '', 'sih': '', 'ya': '', 'yaa': '',
    'kak': '', 'nih': '',
}

_NON_ALNUM = re.compile(r'[^a-z0-9]+')
_REDUPLICATED = re.compile(r'^([a-z]+)2$')
_NUMBER = re.compile(r'^[0-9]+$')


def normalize(text, slang=SLANG):
    """Return the list of normalised tokens for a question."""
    tokens = []
    for token in _NON_ALNUM.sub(' ', text.lower()).split():
        reduplicated = _REDUPLICATED.match(token)
        if reduplicated:
            token = reduplicated.group(1)
        if _NUMBER.match(token):
            token = '0'
        token = slang.get(token, token)
        if token:
            tokens.append(token)
    return tokens


def features(tokens, char_ngrams=CHAR_NGRAMS):
    """Word unigrams, word bigrams and character n-grams inside each word."""
    result = ['w:' + token for token in tokens]
    result += ['b:' + a + ' ' + b for a, b in zip(tokens, tokens[1:])]
    low, high = char_ngrams
    for token in tokens:
        padded = ' ' + token + ' '
        for size in range(low, high + 1):
            for start in range(len(padded) - size + 1):
                result.append('c:' + padded[start:start + size])
    return result


def analyze(text):
    return features(normalize(text))
