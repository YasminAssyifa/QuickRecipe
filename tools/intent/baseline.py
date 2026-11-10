"""Keyword rules used as the comparison baseline for the trained model.

The trained model is only worth shipping if it beats these rules.
Rules are checked in order and the first match wins.
"""
from features import normalize

RULES = [
    ('substitusi_bahan', ['ganti', 'pengganti', 'gantinya', 'diganti', 'substitusi', 'alternatif',
                          'alternatifnya', 'tukar', 'tukeran', 'replace', 'substitute', 'instead',
                          'swap', 'alternative', 'replacement']),
    ('pakai_kulkas', ['kulkas', 'stok', 'persediaan', 'sisa', 'belanja', 'fridge', 'pantry',
                      'leftovers', 'already have', 'shopping']),
    ('info_resep', ['kalori', 'kalorinya', 'berapa lama', 'berapa menit', 'langkah', 'cara',
                    'bahannya', 'calories', 'how long', 'steps', 'ingredients for', 'how do i make']),
    ('bantuan', ['halo', 'hai', 'hi', 'hello', 'help', 'bantuan', 'terima kasih', 'makasih',
                 'thanks', 'thank you', 'kamu siapa', 'who are you', 'bisa apa', 'what can you do',
                 'selamat pagi', 'good morning']),
    ('cari_resep', ['resep', 'masak', 'masakan', 'menu', 'ide', 'rekomendasi', 'camilan', 'sarapan',
                    'makan siang', 'makan malam', 'recipe', 'recipes', 'cook', 'dinner', 'lunch',
                    'breakfast', 'snack', 'meal', 'dessert']),
]
DEFAULT = 'di_luar_topik'


def predict(text):
    padded = ' ' + ' '.join(normalize(text)) + ' '
    for intent, keywords in RULES:
        if any(' ' + keyword + ' ' in padded for keyword in keywords):
            return intent
    return DEFAULT
