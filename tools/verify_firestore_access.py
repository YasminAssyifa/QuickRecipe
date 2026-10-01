import argparse
import json
from pathlib import Path
import secrets
import urllib.error
import urllib.request

from seed_firestore import ROOT, value


def request(url, method='GET', payload=None, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(
        url, method=method, headers=headers,
        data=None if payload is None else json.dumps(payload).encode('utf-8'),
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, {}


def main():
    parser = argparse.ArgumentParser(description='Verify live rules with two disposable accounts and their own test documents.')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--anonymous', action='store_true')
    args = parser.parse_args()
    if not args.apply:
        print('Use --apply to create two temporary accounts, test their subcollections, and clean them up. No existing user data is changed.')
        return
    root = Path(__file__).resolve().parents[1]
    config = json.loads((root / 'android/app/google-services.json').read_text(encoding='utf-8'))
    key = config['client'][0]['api_key'][0]['current_key']
    auth_url = 'https://identitytoolkit.googleapis.com/v1/accounts:'
    accounts = []
    documents = []
    checks = 0

    def check(label, actual, expected=200):
        nonlocal checks
        if actual != expected:
            raise RuntimeError(f'{label}: expected {expected}, received {actual}')
        checks += 1
        print('PASS:', label)

    def write(path, fields, token, timestamp='updatedAt'):
        return request(ROOT + ':commit', 'POST', {
            'writes': [{
                'update': {'name': ROOT.split('/v1/')[1] + '/' + path,
                           'fields': {k: value(v) for k, v in fields.items()}},
                'updateTransforms': [{'fieldPath': timestamp, 'setToServerValue': 'REQUEST_TIME'}],
            }],
        }, token)[0]

    try:
        for _ in range(2):
            email = 'uts-rules-' + secrets.token_hex(10) + '@example.invalid'
            password = secrets.token_urlsafe(24)
            payload = {'returnSecureToken': True}
            if not args.anonymous:
                payload.update(email=email, password=password)
            status, account = request(auth_url + 'signUp?key=' + key, 'POST', payload)
            check('Disposable account registration', status)
            accounts.append(account)
            if args.anonymous:
                continue
            status, logged_in = request(auth_url + 'signInWithPassword?key=' + key, 'POST', {
                'email': email, 'password': password, 'returnSecureToken': True,
            })
            check('Email/password sign-in', status)
            check('Sign-in preserves account UID', logged_in.get('localId') == account['localId'], True)
        owner, other = accounts
        token = owner['idToken']
        check('Unauthenticated catalog access denied', request(ROOT + '/Complete-Flutter-App')[0], 403)
        status, catalog = request(ROOT + '/Complete-Flutter-App?pageSize=100', token=token)
        check('Authenticated catalog read', status)
        recipes = catalog.get('documents', [])
        check('At least 20 recipes', len(recipes) >= 20, True)
        status, categories = request(ROOT + '/App-Category?pageSize=100', token=token)
        check('Authenticated categories read', status)
        actual_categories = [d for d in categories.get('documents', []) if d['fields'].get('name', {}).get('stringValue') != 'All']
        check('At least 5 actual categories', len(actual_categories) >= 5, True)
        recipe_id = recipes[0]['name'].rsplit('/', 1)[-1]
        base = 'users/' + owner['localId']
        fixture = {
            'name': 'Egg', 'ingredientId': 'egg', 'amount': 200,
            'unit': 'g', 'categoryId': 'protein', 'expiry': '2026-12-31', 'notes': '',
        }
        fixtures = [('fridge', fixture), ('collections', {
            'name': 'Temporary test', 'notes': '', 'recipeIds': [recipe_id],
        }), ('favorites', {'recipeId': recipe_id})]
        for module, fields in fixtures:
            path = base + '/' + module + '/' + (recipe_id if module == 'favorites' else 'uts-verification')
            documents.append((path, token))
            timestamp = 'createdAt' if module == 'favorites' else 'updatedAt'
            check(module + ': owner create', write(path, fields, token, timestamp))
            check(module + ': owner read', request(ROOT + '/' + path, token=token)[0])
            check(module + ': other account denied', request(ROOT + '/' + path, token=other['idToken'])[0], 403)
            check(module + ': anonymous denied', request(ROOT + '/' + path)[0], 403)
            check(module + ': other account write denied', write(path, fields, other['idToken'], timestamp), 403)
            if module != 'favorites':
                fields = {**fields, 'name': 'Updated test'}
                check(module + ': owner update', write(path, fields, token))
            if module == 'fridge':
                check('Fridge rejects zero amount', write(path, {**fields, 'amount': 0}, token), 403)
            check(module + ': owner delete', request(ROOT + '/' + path, 'DELETE', token=token)[0])
            check(module + ': deleted record absent', request(ROOT + '/' + path, token=token)[0], 404)
            documents.remove((path, token))
        check('Other profile path denied', request(ROOT + '/' + base, token=other['idToken'])[0], 403)
        print(f'Result: {checks} live checks passed; catalog={len(recipes)}, categories={len(actual_categories)}.')
    finally:
        failures = 0
        for path, token in documents:
            status, _ = request(ROOT + '/' + path, 'DELETE', token=token)
            failures += status not in (200, 404)
        for account in accounts:
            status, _ = request(auth_url + 'delete?key=' + key, 'POST', {'idToken': account['idToken']})
            failures += status != 200
        print('Temporary accounts/documents cleanup: ' + ('PASS' if not failures else 'FAILED'))
        if failures:
            raise RuntimeError('Temporary test cleanup needs attention.')


if __name__ == '__main__':
    main()
