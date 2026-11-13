# Atribusi MASSIVE

`massive_oos.csv` berisi 238 kalimat bahasa Indonesia yang diambil dari dataset
**MASSIVE 1.1** (Amazon), file `id-ID.jsonl`, partisi `train`.

- Sumber: https://github.com/alexa/massive
- Lisensi: Creative Commons Attribution 4.0 International (CC BY 4.0),
  https://creativecommons.org/licenses/by/4.0/
- Hak cipta: Copyright Amazon.com Inc. or its affiliates. MASSIVE merupakan
  terjemahan dan lokalisasi dari SLURP (CC BY 4.0).

Perubahan yang dilakukan (oleh `prepare_massive.py`):

- Hanya teks kalimat yang diambil, tanpa anotasi slot.
- Skenario `cooking`, intent `general_greet`, dan kalimat basa-basi dibuang.
- Kata panggilan (wake word) "olly" dihapus dari kalimat.
- Diambil sampel acak 14 kalimat per skenario (seed 7), lalu semuanya diberi
  label `di_luar_topik`.
