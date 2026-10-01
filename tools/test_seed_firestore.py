import unittest
from seed_firestore import planned, value


class SeedTests(unittest.TestCase):
    def test_existing_id_and_name_are_skipped(self):
        existing = [{'name': 'projects/test/documents/recipes/old', 'fields': {'name': value('Puding')}}]
        entries = [{'id': 'old', 'name': 'Changed'}, {'id': 'new', 'name': ' puding '}]
        self.assertEqual(planned('recipes', entries, existing), [])

    def test_create_has_no_overwrite_precondition(self):
        writes = planned('recipes', [{'id': 'new', 'name': 'Rice'}], [])
        self.assertEqual(writes[0]['currentDocument'], {'exists': False})

    def test_duplicate_input_is_skipped(self):
        entry = {'id': 'new', 'name': 'Rice'}
        self.assertEqual(len(planned('recipes', [entry, entry], [])), 1)

    def test_array_types_match_firestore(self):
        self.assertEqual(value([50, 2.5]), {'arrayValue': {'values': [{'integerValue': '50'}, {'doubleValue': 2.5}]}})


if __name__ == '__main__':
    unittest.main()
