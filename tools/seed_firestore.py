import argparse
import json
import os
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request

ROOT = 'https://firestore.googleapis.com/v1/projects/quickrecipe-00/databases/(default)/documents'


def request(path, payload=None):
    headers = {'Content-Type': 'application/json'}
    token = os.environ.get('FIREBASE_ID_TOKEN') or os.environ.get('GOOGLE_OAUTH_ACCESS_TOKEN')
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(ROOT + path, headers=headers,
                                 data=None if payload is None else json.dumps(payload).encode())
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def documents(collection):
    result = []
    token = ''
    while True:
        page = request('/' + collection + '?pageSize=100' +
                       ('&pageToken=' + urllib.parse.quote(token, safe='') if token else ''))
        result.extend(page.get('documents', []))
        token = page.get('nextPageToken')
        if not token:
            return result


def value(item):
    if isinstance(item, str):
        return {'stringValue': item}
    if isinstance(item, int):
        return {'integerValue': str(item)}
    if isinstance(item, float):
        return {'doubleValue': item}
    if isinstance(item, list):
        return {'arrayValue': {'values': [value(element) for element in item]}}
    raise ValueError('Unsupported field type')


def planned(collection, entries, existing):
    ids = {doc['name'].rsplit('/', 1)[-1] for doc in existing}
    names = {doc['fields'].get('name', {}).get('stringValue', '').strip().casefold() for doc in existing}
    writes = []
    for entry in entries:
        if entry['id'] in ids or entry['name'].strip().casefold() in names:
            continue
        fields = {key: value(item) for key, item in entry.items() if key != 'id'}
        writes.append({'update': {'name': ROOT.split('/v1/')[1] + '/' + collection + '/' + entry['id'],
                                  'fields': fields}, 'currentDocument': {'exists': False}})
        ids.add(entry['id'])
        names.add(entry['name'].strip().casefold())
    return writes


def main():
    parser = argparse.ArgumentParser(description='Add UTS demo recipes without changing existing documents.')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--data', type=Path, default=Path(__file__).with_name('seed_recipes.json'))
    args = parser.parse_args()
    data = json.loads(args.data.read_text(encoding='utf-8'))
    for recipe in data['Complete-Flutter-App']:
        if not recipe['ingredientsName'] or len(recipe['ingredientsName']) != len(recipe['ingredientsAmount']):
            raise ValueError('Ingredient arrays must have matching lengths')
        if not recipe['step'] or any(amount <= 0 for amount in recipe['ingredientsAmount']):
            raise ValueError('Steps and positive amounts are required')
    before = {collection: documents(collection) for collection in data}
    writes = [write for collection, entries in data.items() for write in planned(collection, entries, before[collection])]
    print(f'Project: quickrecipe-00. New documents: {len(writes)}. Existing documents will not be updated.')
    for write in writes:
        print('ADD', write['update']['name'].split('/documents/')[1])
    if not args.apply or not writes:
        print('No writes performed.' if not args.apply else 'Already seeded.')
        return
    backup = Path(__file__).resolve().parent.parent / '.dart_tool' / 'firestore_seed_before.json'
    backup.parent.mkdir(exist_ok=True)
    backup.write_text(json.dumps(before, indent=2), encoding='utf-8')
    request(':commit', {'writes': writes})
    for collection, old_docs in before.items():
        after = documents(collection)
        indexed = {doc['name']: doc for doc in after}
        for old in old_docs:
            current = indexed.get(old['name'])
            if current is None or current['fields'] != old['fields'] or current['updateTime'] != old['updateTime']:
                raise RuntimeError('Existing document changed concurrently; inspect backup: ' + str(backup))
        print(f'{collection}: {len(after)} documents; existing documents unchanged.')


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        raise SystemExit(f'Firestore HTTP {error.code}. No rules were changed. Use an authorized token if access is denied.')
