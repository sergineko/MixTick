#!/usr/bin/env python3
"""Real local Supabase Auth/PostgREST/Storage tests, never a mock or remote run.

Usage: python scripts/test_database_api.py --cli .tooling/supabase/supabase.exe
Only the public anon key and A/B/C access tokens are used for API requests.
Docker psql is used solely for isolated fixture cleanup and DB introspection.
"""
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import os
import subprocess
import time
import unittest
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import Request, urlopen
import uuid

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE = ROOT / 'docs/reports/phase02/evidence'
INGREDIENT = '10000000-0000-4000-8000-000000000001'
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jEukAAAAASUVORK5CYII=')


class DatabaseApiTests(unittest.TestCase):
    cli = None

    @classmethod
    def setUpClass(cls):
        import tomllib
        config = tomllib.loads((ROOT / 'supabase/config.toml').read_text('utf-8'))
        if config['project_id'] != 'mixtick-phase02':
            raise RuntimeError('Refusing to run against a different project')
        env = dict(os.environ, DO_NOT_TRACK='1', CI='true')
        result = subprocess.run([str(cls.cli), 'status', '-o', 'json', '--workdir', str(ROOT)],
                                capture_output=True, text=True, env=env, check=True)
        # Never print or save the full status: it also contains local admin keys.
        status = json.loads(result.stdout)
        cls.base = status['API_URL'].rstrip('/')
        if urlparse(cls.base).hostname not in ('127.0.0.1', 'localhost', '::1'):
            raise RuntimeError('Remote hosts are forbidden in this test suite')
        cls.anon = status['ANON_KEY']
        cls.users = {}
        cls.photos = []
        cls.cleanup_verified = False
        suffix = uuid.uuid4().hex[:10]
        for letter in ('a', 'b', 'c'):
            payload = {'email': f'mixtick-{suffix}-{letter}@example.test',
                       'password': f'Test-only-{uuid.uuid4().hex}'}
            code, data = cls.http('POST', '/auth/v1/signup', body=payload)
            if code != 200 or not data.get('access_token'):
                raise RuntimeError(f'Local Auth signup failed for {letter}: HTTP {code}; no tokens logged')
            user = {'id': str(uuid.UUID(data['user']['id'])), 'token': data['access_token'],
                    'username': f'test_{suffix}_{letter}'}
            cls.users[letter] = user
            code, _ = cls.http('POST', '/rest/v1/profiles', user=user,
                              body={'username': user['username'], 'display_name': f'Prueba {letter.upper()}'})
            if code != 201:
                raise RuntimeError(f'Local profile creation failed for {letter}: HTTP {code}')

    @classmethod
    def tearDownClass(cls):
        for user, path in cls.photos:
            cls.http('DELETE', '/storage/v1/object/recipe-photos', user=user, body={'prefixes': [path]})
        # Only UUIDs returned for this run's actual Auth accounts may be deleted.
        ids = ','.join("'" + str(uuid.UUID(u['id'])) + "'::uuid" for u in cls.users.values())
        if ids:
            cls.sql(f'DELETE FROM auth.users WHERE id IN ({ids});')
            remaining = cls.sql(f'SELECT count(*) FROM auth.users WHERE id IN ({ids});')
            if remaining != '0':
                raise RuntimeError('Fixture cleanup did not remove this run\'s Auth identities')
            cls.cleanup_verified = True

    @classmethod
    def sql(cls, query):
        result = subprocess.run(['docker', 'exec', '-i', 'supabase_db_mixtick-phase02',
                                 'psql', '-U', 'postgres', '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1'],
                                input=query, capture_output=True, text=True, encoding='utf-8', check=True)
        return result.stdout.strip()

    @classmethod
    def http(cls, method, path, user=None, body=None, raw=None, headers=None):
        url = path if path.startswith('http') else cls.base + path
        if urlparse(url).hostname not in ('127.0.0.1', 'localhost', '::1'):
            raise RuntimeError('Remote test request refused')
        hdr = {'apikey': cls.anon, 'Authorization': 'Bearer ' + (user['token'] if user else cls.anon),
               'Content-Type': 'application/json', 'Prefer': 'return=representation'}
        hdr.update(headers or {})
        data = raw if raw is not None else json.dumps(body).encode('utf-8') if body is not None else None
        request = Request(url, data=data, headers=hdr, method=method)
        try:
            with urlopen(request, timeout=20) as response:
                code, content = response.status, response.read()
        except HTTPError as error:
            code, content = error.code, error.read()
        try:
            return code, json.loads(content)
        except (json.JSONDecodeError, UnicodeDecodeError):
            return code, content

    def rpc(self, letter, function, params, expected=None):
        if expected is None:
            expected = 204 if function in ('revoke_list_member', 'leave_list', 'delete_shopping_item') else 200
        code, data = self.http('POST', '/rest/v1/rpc/' + function,
                               user=self.users[letter] if letter else None, body=params)
        self.assertEqual(code, expected, f'{function}: HTTP {code}; {data if expected == 200 else "expected denial"}')
        return data

    def rows(self, letter, table, query=''):
        code, data = self.http('GET', '/rest/v1/' + table + query,
                               user=self.users[letter] if letter else None)
        self.assertEqual(code, 200, f'{table}: HTTP {code}')
        return data

    def deny(self, method, path, letter='b', body=None):
        code, data = self.http(method, path, self.users[letter] if letter else None, body)
        self.assertLess(code, 500, 'Permission checks must not produce SQL/RLS recursion errors')
        self.assertTrue(code in (400, 401, 403, 404, 406, 409, 422) or
                        (code in (200, 204) and data in ([], b'')), f'Expected denial or zero rows, got HTTP {code}')
        return code

    def recipe(self, owner='a', ingredients=None, steps=None, overrides=None):
        recipe = {'title': 'Receta privada de prueba', 'category': 'principal', 'servings': 2,
                  'description': 'Nota privada que no debe llegar a colaboradores'}
        recipe.update(overrides or {})
        return self.rpc(owner, 'save_recipe', {'p_recipe_id': None, 'p_expected_version': None,
                       'p_recipe': recipe, 'p_ingredients': ingredients if ingredients is not None else
                       [{'ingredient_id': INGREDIENT, 'quantity': 2, 'unit': 'ud'},
                        {'custom_name': 'Hierba de prueba', 'optional': True}],
                       'p_steps': steps if steps is not None else ['Preparar los ingredientes.', 'Cocinar.']})

    def publish(self, recipe, visibility='public'):
        version = self.rows('a', 'recipes', '?id=eq.' + recipe)[0]['version']
        return self.rpc('a', 'set_recipe_visibility', {'p_recipe_id': recipe,
                        'p_visibility': visibility, 'p_expected_version': version})

    def shopping_list(self):
        code, data = self.http('POST', '/rest/v1/shopping_lists', self.users['a'], {'title': 'Compra de prueba'})
        self.assertEqual(code, 201, f'List creation: HTTP {code}; {data}')
        return data[0]['id']

    def invite(self, list_id, recipient='b'):
        return self.rpc('a', 'invite_to_list', {'p_list_id': list_id, 'p_username': self.users[recipient]['username']})

    def accept(self, invitation, user='b'):
        return self.rpc(user, 'respond_to_invitation', {'p_invitation_id': invitation, 'p_accept': True})

    def item(self, list_id, user='a', name='Tomate'):
        return self.rpc(user, 'add_shopping_item', {'p_list_id': list_id, 'p_item': {'name': name, 'quantity': 1, 'unit': 'ud'}})

    def test_01_private_public_private_including_all_relations(self):
        recipe = self.recipe(overrides={'visibility': 'public'})
        self.assertEqual(self.rows('a', 'recipes', '?id=eq.' + recipe)[0]['visibility'], 'private')
        for user in ('b', 'c'):
            for table in ('recipes', 'recipe_ingredients', 'recipe_steps', 'recipe_likes', 'recipe_comments', 'recipe_saves'):
                field = 'id' if table == 'recipes' else 'recipe_id'
                self.assertEqual(self.rows(user, table, f'?{field}=eq.{recipe}'), [])
            self.assertEqual(self.rows(user, 'recipes', f'?id=eq.{recipe}&select=*,recipe_ingredients(*),recipe_steps(*)'), [])
        self.publish(recipe)
        self.assertEqual(len(self.rows('b', 'recipes', '?id=eq.' + recipe)), 1)
        self.assertEqual(len(self.rows('b', 'recipe_ingredients', '?recipe_id=eq.' + recipe)), 2)
        for table, body in [('recipe_saves', {'recipe_id': recipe}), ('recipe_likes', {'recipe_id': recipe}),
                            ('recipe_comments', {'recipe_id': recipe, 'content': 'Comentario de prueba'})]:
            code, _ = self.http('POST', '/rest/v1/' + table, self.users['b'], body)
            self.assertEqual(code, 201)
        first_publication = self.rows('a', 'recipes', '?id=eq.' + recipe)[0]['published_at']
        self.publish(recipe, 'private')
        for user in ('b', 'c'):
            for table in ('recipes', 'recipe_ingredients', 'recipe_steps', 'recipe_likes', 'recipe_comments', 'recipe_saves'):
                self.assertEqual(self.rows(user, table, f'?{"id" if table == "recipes" else "recipe_id"}=eq.{recipe}'), [])
        self.publish(recipe)
        self.assertEqual(self.rows('a', 'recipes', '?id=eq.' + recipe)[0]['published_at'], first_publication)

    def test_02_nonowner_cannot_write_or_spoof_identity(self):
        recipe = self.recipe()
        self.deny('PATCH', '/rest/v1/recipes?id=eq.' + recipe, body={'title': 'Alterada'})
        self.deny('DELETE', '/rest/v1/recipes?id=eq.' + recipe)
        self.deny('POST', '/rest/v1/rpc/set_recipe_visibility', body={'p_recipe_id': recipe, 'p_visibility': 'public', 'p_expected_version': 1})
        self.deny('POST', '/rest/v1/rpc/save_recipe', body={'p_recipe_id': recipe, 'p_expected_version': 1,
                  'p_recipe': {'title': 'Alterada', 'category': 'x', 'servings': 1},
                  'p_ingredients': [{'ingredient_id': INGREDIENT}], 'p_steps': ['Paso']})
        for table in ('recipe_ingredients', 'recipe_steps'):
            self.deny('POST', '/rest/v1/' + table, 'a', {'recipe_id': recipe})
        self.deny('POST', '/rest/v1/profiles', 'b', {'user_id': self.users['a']['id'], 'username': 'spoof', 'display_name': 'Spoof'})
        self.assertEqual(self.rows('a', 'recipes', '?id=eq.' + recipe)[0]['title'], 'Receta privada de prueba')

    def test_03_recipe_create_update_roll_back_completely(self):
        before = len(self.rows('a', 'recipes'))
        code, _ = self.http('POST', '/rest/v1/rpc/save_recipe', self.users['a'], {
            'p_recipe_id': None, 'p_expected_version': None,
            'p_recipe': {'title': 'Inválida', 'category': 'x', 'servings': 1},
            'p_ingredients': [{'ingredient_id': INGREDIENT}, {'custom_name': 'Inválido', 'quantity': -1}],
            'p_steps': ['Paso']})
        self.assertEqual(code, 400)
        self.assertEqual(len(self.rows('a', 'recipes')), before)
        recipe = self.recipe()
        original = self.rows('a', 'recipes', '?id=eq.' + recipe)[0]
        original_lines = self.rows('a', 'recipe_ingredients', '?recipe_id=eq.' + recipe)
        code, _ = self.http('POST', '/rest/v1/rpc/save_recipe', self.users['a'], {
            'p_recipe_id': recipe, 'p_expected_version': original['version'],
            'p_recipe': {'title': 'No debe persistir', 'category': 'x', 'servings': 3},
            'p_ingredients': [{'ingredient_id': INGREDIENT}], 'p_steps': ['Paso válido', '']})
        self.assertEqual(code, 400)
        self.assertEqual(self.rows('a', 'recipes', '?id=eq.' + recipe)[0], original)
        self.assertEqual(self.rows('a', 'recipe_ingredients', '?recipe_id=eq.' + recipe), original_lines)

    def test_04_acceptance_and_revocation_enforced_by_server(self):
        list_id = self.shopping_list()
        item = self.item(list_id)
        invitation = self.invite(list_id)
        self.assertEqual(self.rows('b', 'shopping_lists', '?id=eq.' + list_id), [])
        self.assertEqual(self.rows('b', 'shopping_items', '?list_id=eq.' + list_id), [])
        self.accept(invitation)
        self.assertEqual(len(self.rows('b', 'shopping_lists', '?id=eq.' + list_id)), 1)
        self.rpc('b', 'update_shopping_item', {'p_item_id': item, 'p_expected_version': 1, 'p_changes': {'is_purchased': True}})
        self.assertTrue(self.rows('a', 'shopping_items', '?id=eq.' + item)[0]['is_purchased'])
        for table in ('shopping_lists', 'shopping_items', 'shopping_list_members', 'shopping_list_invitations'):
            field = 'id' if table == 'shopping_lists' else 'list_id'
            self.assertEqual(self.rows('c', table, f'?{field}=eq.{list_id}'), [])
        self.deny('POST', '/rest/v1/rpc/add_shopping_item', 'c', {'p_list_id': list_id, 'p_item': {'name': 'Intruso'}})
        self.deny('POST', '/rest/v1/rpc/update_shopping_item', 'c', {'p_item_id': item, 'p_expected_version': 2, 'p_changes': {'name': 'Intruso'}})
        self.deny('POST', '/rest/v1/rpc/delete_shopping_item', 'c', {'p_item_id': item, 'p_expected_version': 2})
        self.deny('POST', '/rest/v1/rpc/invite_to_list', 'b', {'p_list_id': list_id, 'p_username': self.users['c']['username']})
        self.deny('DELETE', '/rest/v1/shopping_lists?id=eq.' + list_id, 'b')
        self.rpc('a', 'revoke_list_member', {'p_list_id': list_id, 'p_user_id': self.users['b']['id']})
        for table in ('shopping_lists', 'shopping_items', 'shopping_list_members'):
            self.assertEqual(self.rows('b', table, f'?{"id" if table == "shopping_lists" else "list_id"}=eq.{list_id}'), [])
        self.deny('POST', '/rest/v1/rpc/update_shopping_item', 'b', {'p_item_id': item, 'p_expected_version': 2, 'p_changes': {'name': 'Intruso'}})
        self.deny('POST', '/rest/v1/rpc/add_shopping_item', 'b', {'p_list_id': list_id, 'p_item': {'name': 'Intruso'}})
        self.deny('POST', '/rest/v1/rpc/delete_shopping_item', 'b', {'p_item_id': item, 'p_expected_version': 2})
        self.deny('POST', '/rest/v1/rpc/respond_to_invitation', 'b', {'p_invitation_id': invitation, 'p_accept': True})

    def test_05_recipient_only_and_concurrent_acceptance(self):
        list_id = self.shopping_list()
        invitation = self.invite(list_id)
        for user in ('a', 'c'):
            self.deny('POST', '/rest/v1/rpc/respond_to_invitation', user, {'p_invitation_id': invitation, 'p_accept': True})
        self.deny('POST', '/rest/v1/shopping_list_members', 'b', {'list_id': list_id, 'user_id': self.users['b']['id']})
        self.deny('POST', '/rest/v1/shopping_list_invitations', 'c', {'list_id': list_id, 'sender_id': self.users['a']['id'], 'invitee_id': self.users['c']['id']})
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _: self.http('POST', '/rest/v1/rpc/respond_to_invitation', self.users['b'],
                {'p_invitation_id': invitation, 'p_accept': True}), range(4)))
        self.assertTrue(all(code == 200 and data == list_id for code, data in results))
        self.assertEqual(len(self.rows('a', 'shopping_list_members', '?list_id=eq.' + list_id)), 1)
        self.rpc('b', 'leave_list', {'p_list_id': list_id})
        self.deny('POST', '/rest/v1/rpc/respond_to_invitation', 'b', {'p_invitation_id': invitation, 'p_accept': True})

    def test_06_duplicate_interactions_invites_and_foreign_keys(self):
        recipe = self.recipe()
        self.publish(recipe)
        for table in ('recipe_likes', 'recipe_saves'):
            code, _ = self.http('POST', '/rest/v1/' + table, self.users['b'], {'recipe_id': recipe})
            self.assertEqual(code, 201)
            self.assertEqual(self.deny('POST', '/rest/v1/' + table, 'b', {'recipe_id': recipe}), 409)
        list_id = self.shopping_list()
        self.invite(list_id)
        self.assertEqual(self.deny('POST', '/rest/v1/rpc/invite_to_list', 'a', {'p_list_id': list_id, 'p_username': self.users['b']['username']}), 409)
        self.assertEqual(self.deny('POST', '/rest/v1/user_follows', 'a', {'followed_id': str(uuid.uuid4())}), 409)
        self.assertEqual(self.deny('POST', '/rest/v1/user_follows', 'a', {'followed_id': self.users['a']['id']}), 400)
        self.deny('POST', '/rest/v1/rpc/add_shopping_item', 'a', {'p_list_id': list_id,
            'p_item': {'name': 'No existe', 'ingredient_id': str(uuid.uuid4())}})

    def test_07_concurrent_item_edits_require_matching_version(self):
        list_id = self.shopping_list()
        self.accept(self.invite(list_id))
        item = self.item(list_id)
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda user: self.http('POST', '/rest/v1/rpc/update_shopping_item', self.users[user],
                {'p_item_id': item, 'p_expected_version': 1, 'p_changes': {'quantity': 2 if user == 'a' else 3}}), ('a', 'b')))
        self.assertEqual(sorted(code for code, _ in results), [200, 409], str(results))
        current = self.rows('a', 'shopping_items', '?id=eq.' + item)[0]
        self.assertEqual(current['version'], 2)
        self.deny('PATCH', '/rest/v1/shopping_items?id=eq.' + item, 'b', {'quantity': 999})
        self.assertEqual(self.rows('a', 'shopping_items', '?id=eq.' + item)[0]['quantity'], current['quantity'])

    def test_08_import_idempotent_no_private_origin_leak(self):
        recipe = self.recipe()
        list_id = self.shopping_list()
        self.accept(self.invite(list_id))
        params = {'p_list_id': list_id, 'p_recipe_id': recipe, 'p_request_id': str(uuid.uuid4()), 'p_ordinals': [0, 1]}
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: self.http('POST', '/rest/v1/rpc/import_recipe_ingredients', self.users['a'], params), range(2)))
        self.assertTrue(all(code == 200 for code, _ in results))
        self.assertEqual(results[0][1], results[1][1])
        lines = self.rows('b', 'shopping_items', '?list_id=eq.' + list_id)
        self.assertEqual(len(lines), 2)
        self.assertNotIn(recipe, json.dumps(lines))
        self.assertNotIn('Receta privada', json.dumps(lines))
        self.assertNotIn('Nota privada', json.dumps(lines))
        self.assertEqual(self.rows('b', 'recipes', '?id=eq.' + recipe), [])
        self.deny('POST', '/rest/v1/rpc/import_recipe_ingredients', 'b', params)
        self.deny('POST', '/rest/v1/rpc/import_recipe_ingredients', 'a', dict(params, p_ordinals=[0]))
        self.rpc('a', 'delete_shopping_item', {'p_item_id': lines[0]['id'], 'p_expected_version': lines[0]['version']})
        self.rpc('a', 'import_recipe_ingredients', params)
        self.assertEqual(len(self.rows('a', 'shopping_items', '?list_id=eq.' + list_id)), 1, 'Retry must not resurrect a deleted line')

    def test_09_import_invalid_selection_is_atomic(self):
        recipe = self.recipe()
        list_id = self.shopping_list()
        self.deny('POST', '/rest/v1/rpc/import_recipe_ingredients', 'a', {'p_list_id': list_id, 'p_recipe_id': recipe,
            'p_request_id': str(uuid.uuid4()), 'p_ordinals': [0, 99]})
        self.assertEqual(self.rows('a', 'shopping_items', '?list_id=eq.' + list_id), [])

    def test_10_catalog_uses_curated_ids_without_false_equivalence(self):
        for name in ('tomate', 'TOMATES', '  tOMÁTES  '):
            self.assertEqual(self.rpc('b', 'resolve_ingredient', {'p_name': name}), INGREDIENT)
        for name in ('aceite', 'harina', 'pimiento', 'producto no catalogado'):
            self.assertIsNone(self.rpc('b', 'resolve_ingredient', {'p_name': name}))
        milk = self.rpc('b', 'resolve_ingredient', {'p_name': 'LECHE'})
        cream = self.rpc('b', 'resolve_ingredient', {'p_name': 'nata'})
        self.assertNotEqual(milk, cream)
        self.assertEqual(len(self.rows('a', 'ingredients')), 50)
        self.deny('POST', '/rest/v1/ingredients', 'a', {'canonical_name_es': 'Intruso', 'approved': True})
        self.deny('POST', '/rest/v1/ingredient_aliases', 'a', {'ingredient_id': milk, 'alias_es': 'nata'})

    def test_11_storage_privacy_listing_upload_and_expiry(self):
        recipe = self.recipe()
        path = f'{self.users["a"]["id"]}/{recipe}/{uuid.uuid4()}.png'
        code, _ = self.http('POST', '/storage/v1/object/recipe-photos/' + path, self.users['a'], raw=PNG,
                            headers={'Content-Type': 'image/png', 'x-upsert': 'false', 'Cache-Control': 'max-age=0'})
        self.assertEqual(code, 200)
        self.photos.append((self.users['a'], path))
        self.rpc('a', 'set_recipe_photo', {'p_recipe_id': recipe, 'p_path': path, 'p_expected_version': 1})
        for user in ('b', 'c'):
            self.deny('GET', '/storage/v1/object/authenticated/recipe-photos/' + path, user)
            code, data = self.http('POST', '/storage/v1/object/list/recipe-photos', self.users[user],
                                    {'prefix': f'{self.users["a"]["id"]}/{recipe}/'})
            self.assertEqual((code, data), (200, []))
            self.deny('POST', '/storage/v1/object/sign/recipe-photos/' + path, user, {'expiresIn': 60})
        self.deny('GET', '/storage/v1/object/public/recipe-photos/' + path, None)
        forbidden_path = f'{self.users["a"]["id"]}/{recipe}/{uuid.uuid4()}.png'
        code, _ = self.http('POST', '/storage/v1/object/recipe-photos/' + forbidden_path, self.users['b'], raw=PNG,
                            headers={'Content-Type': 'image/png'})
        self.assertIn(code, (400, 403))
        self.publish(recipe)
        code, data = self.http('GET', '/storage/v1/object/authenticated/recipe-photos/' + path, self.users['b'])
        self.assertEqual(code, 200)
        self.assertEqual(data, PNG)
        code, signed = self.http('POST', '/storage/v1/object/sign/recipe-photos/' + path, self.users['b'], {'expiresIn': 3})
        self.assertEqual(code, 200)
        link = signed['signedURL']
        link = self.base + (link if link.startswith('/storage/') else '/storage/v1' + link)
        self.publish(recipe, 'private')
        self.deny('GET', '/storage/v1/object/authenticated/recipe-photos/' + path, 'b')
        self.deny('POST', '/storage/v1/object/sign/recipe-photos/' + path, 'b', {'expiresIn': 60})
        code, _ = self.http('GET', link)
        self.assertEqual(code, 200, 'Already signed capability remains usable until expiry; no instant revocation claim')
        time.sleep(4)
        code, _ = self.http('GET', link)
        self.assertIn(code, (400, 401, 403, 404), 'Expired signed URL must no longer serve the private image')

    def test_12_anon_and_private_schema_denied(self):
        for table in ('profiles', 'ingredients', 'recipes', 'shopping_lists'):
            self.deny('GET', '/rest/v1/' + table, None)
        self.deny('POST', '/rest/v1/rpc/invite_to_list', None, {'p_list_id': str(uuid.uuid4()), 'p_username': 'anyone'})
        code, _ = self.http('GET', '/rest/v1/shopping_imports', self.users['a'], headers={'Accept-Profile': 'private'})
        self.assertEqual(code, 406)

    def test_13_cascades_delete_relationships_and_list_resources(self):
        recipe = self.recipe()
        list_id = self.shopping_list()
        self.accept(self.invite(list_id))
        self.item(list_id)
        code, _ = self.http('DELETE', '/rest/v1/recipes?id=eq.' + recipe, self.users['a'])
        self.assertEqual(code, 200)
        for table in ('recipe_ingredients', 'recipe_steps'):
            self.assertEqual(self.rows('a', table, '?recipe_id=eq.' + recipe), [])
        code, _ = self.http('DELETE', '/rest/v1/shopping_lists?id=eq.' + list_id, self.users['a'])
        self.assertEqual(code, 200)
        for table in ('shopping_list_members', 'shopping_list_invitations', 'shopping_items'):
            self.assertEqual(self.rows('a', table, '?list_id=eq.' + list_id), [])

    def test_14_block_and_report_validation(self):
        recipe = self.recipe()
        self.publish(recipe)
        report = self.rpc('b', 'submit_report', {'p_target_type': 'recipe', 'p_target_id': recipe,
                          'p_reason': 'Contenido de prueba denunciado'})
        self.assertEqual(self.rows('a', 'content_reports', '?id=eq.' + report), [])
        self.deny('PATCH', '/rest/v1/content_reports?id=eq.' + report, 'b', {'status': 'closed'})
        self.deny('POST', '/rest/v1/rpc/submit_report', 'b', {'p_target_type': 'recipe', 'p_target_id': str(uuid.uuid4()), 'p_reason': 'No existe esa receta'})
        code, _ = self.http('POST', '/rest/v1/user_blocks', self.users['a'], {'blocked_id': self.users['b']['id']})
        self.assertEqual(code, 201)
        try:
            self.assertEqual(self.rows('b', 'recipes', '?id=eq.' + recipe), [])
            self.assertEqual(self.rows('b', 'profiles', '?user_id=eq.' + self.users['a']['id']), [])
            self.assertEqual(self.rows('c', 'user_blocks'), [])
        finally:
            self.http('DELETE', '/rest/v1/user_blocks?blocked_id=eq.' + self.users['b']['id'], self.users['a'])

    def test_15_complete_recipe_update_and_stale_version(self):
        # Use B to keep independent per-user recipe quotas within bounds.
        recipe = self.recipe('b')
        params = {'p_recipe_id': recipe, 'p_expected_version': 1,
                  'p_recipe': {'title': 'Receta actualizada', 'category': 'postre', 'servings': 4},
                  'p_ingredients': [{'custom_name': '  Hierba Ácida  '}], 'p_steps': ['Paso nuevo']}
        self.assertEqual(self.rpc('b', 'save_recipe', params), recipe)
        self.assertEqual(self.rows('b', 'recipes', '?id=eq.' + recipe)[0]['version'], 2)
        lines = self.rows('b', 'recipe_ingredients', '?recipe_id=eq.' + recipe)
        self.assertEqual(len(lines), 1)
        self.assertEqual(lines[0]['custom_key'], 'hierba acida')
        self.assertEqual(self.deny('POST', '/rest/v1/rpc/save_recipe', 'b', params), 409)
        self.assertEqual(self.rows('b', 'recipes', '?id=eq.' + recipe)[0]['title'], 'Receta actualizada')

    def test_16_comment_rate_limit_cannot_be_bypassed_by_direct_api(self):
        recipe = self.recipe('b')
        self.rpc('b', 'set_recipe_visibility', {'p_recipe_id': recipe, 'p_visibility': 'public', 'p_expected_version': 1})
        for n in range(20):
            code, data = self.http('POST', '/rest/v1/recipe_comments', self.users['c'], {'recipe_id': recipe, 'content': f'Prueba {n}'})
            self.assertEqual(code, 201)
        # Removing content must not reset the backend creation quota.
        code, _ = self.http('DELETE', '/rest/v1/recipe_comments?id=eq.' + data[0]['id'], self.users['c'])
        self.assertEqual(code, 200)
        code, _ = self.http('POST', '/rest/v1/recipe_comments', self.users['c'], {'recipe_id': recipe, 'content': 'Debe limitarse'})
        self.assertEqual(code, 429)

    def test_17_blocked_and_rejected_invitations_never_grant_membership(self):
        list_id = self.shopping_list()
        invitation = self.invite(list_id)
        code, _ = self.http('POST', '/rest/v1/user_blocks', self.users['a'], {'blocked_id': self.users['b']['id']})
        self.assertEqual(code, 201)
        try:
            self.deny('POST', '/rest/v1/rpc/respond_to_invitation', 'b', {'p_invitation_id': invitation, 'p_accept': True})
            self.deny('POST', '/rest/v1/rpc/invite_to_list', 'a', {'p_list_id': list_id, 'p_username': self.users['b']['username']})
        finally:
            self.http('DELETE', '/rest/v1/user_blocks?blocked_id=eq.' + self.users['b']['id'], self.users['a'])
        self.rpc('b', 'respond_to_invitation', {'p_invitation_id': invitation, 'p_accept': False})
        self.deny('POST', '/rest/v1/rpc/respond_to_invitation', 'b', {'p_invitation_id': invitation, 'p_accept': True})
        self.assertEqual(self.rows('a', 'shopping_list_members', '?list_id=eq.' + list_id), [])

    def test_18_deleted_recipe_enqueues_private_blob_cleanup(self):
        # Real DB trigger in a rolled-back transaction; leaves the actual blob
        # accessible to its owner for normal Storage API teardown afterwards.
        user, path = self.photos[0]
        recipe_id = str(uuid.UUID(path.split('/')[1]))
        output = self.sql(f"BEGIN; DELETE FROM public.recipes WHERE id = '{recipe_id}'::uuid; "
                          f"SELECT count(*) FROM private.storage_cleanup_jobs WHERE object_name = '{path}'; ROLLBACK;")
        self.assertIn('1', output.splitlines())
        self.assertEqual(len(self.rows('a', 'recipes', '?id=eq.' + recipe_id)), 1)

    def test_19_nonmember_item_error_does_not_disclose_existence(self):
        list_id = self.shopping_list()
        item = self.item(list_id)
        responses = []
        for identifier in (item, str(uuid.uuid4())):
            code, data = self.http('POST', '/rest/v1/rpc/update_shopping_item', self.users['c'],
                                   {'p_item_id': identifier, 'p_expected_version': 1, 'p_changes': {'name': 'Intruso'}})
            self.assertEqual(code, 403)
            responses.append(data)
        self.assertEqual(responses[0], responses[1])

    def test_20_known_free_text_is_saved_as_canonical_id(self):
        recipe = self.recipe('b', ingredients=[{'custom_name': '  tOMÁTES  '}])
        line = self.rows('b', 'recipe_ingredients', '?recipe_id=eq.' + recipe)[0]
        self.assertEqual(line['ingredient_id'], INGREDIENT)
        self.assertIsNone(line['custom_name'])
        self.assertIsNone(line['custom_key'])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cli', default=str(ROOT / '.tooling/supabase/supabase.exe'))
    args = parser.parse_args()
    DatabaseApiTests.cli = Path(args.cli).resolve()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(DatabaseApiTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / 'api-results.json').write_text(json.dumps({
        'tests_run': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
        'skipped': len(result.skipped), 'status': 'PASS' if result.wasSuccessful() else 'FAIL',
        'mode': 'real local Supabase Auth + PostgREST + Storage; no mock and no admin API key',
        'fixture_accounts_removed': getattr(DatabaseApiTests, 'cleanup_verified', False),
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    raise SystemExit(main())
