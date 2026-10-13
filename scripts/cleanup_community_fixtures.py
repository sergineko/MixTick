"""Trusted host teardown of this run's local fixtures, never permission proof.

Only identities recorded by real Auth and validated as phase05 example.test
accounts may be removed. Storage API is used for physical fixture cleanup;
the application's deferred cleanup worker remains unimplemented.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import uuid
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent

def sql(query):
    result = subprocess.run(['docker', 'exec', '-i', 'supabase_db_mixtick-phase02', 'psql', '-U', 'postgres', '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1'],input=query,capture_output=True,text=True,check=True)
    return result.stdout.strip()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--fixtures',default='.tooling/phase05-fixtures.json')
    args=parser.parse_args()
    path=(ROOT / args.fixtures).resolve()
    if path.parent != (ROOT / '.tooling').resolve():
        raise RuntimeError('Fixture manifest must be within the ignored tooling directory')
    data=json.loads(path.read_text('utf-8-sig'))
    owned={str(uuid.UUID(u['id'])):u['email'] for u in data['users']}
    for uid,email in owned.items():
        if not re.fullmatch(r'mixtick-p5-(?:native-)?[0-9a-f]{10}-[abc]@example\.test',email):
            raise RuntimeError('Not a phase05 fixture identity')
        actual=sql(f"select email from auth.users where id='{uid}'::uuid;")
        if actual not in ('',email):
            raise RuntimeError('Recorded fixture identity mismatch')
    cli=ROOT / '.tooling/supabase/supabase.exe'
    status=json.loads(subprocess.run([str(cli),'status','-o','json'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
    if status['API_URL'].rstrip('/') != 'http://127.0.0.1:54321':
        raise RuntimeError('Only the isolated local backend is permitted')
    # Admin key used only in this trusted cleanup process; never Flutter,
    # assertions about permissions, output, fixture manifest or Git.
    token=status['SERVICE_ROLE_KEY']
    paths=set(data.get('photos',[]))
    for uid in owned:
        rows=sql(f"select name from storage.objects where bucket_id='recipe-photos' and split_part(name,'/',1)='{uid}';")
        paths.update(rows.splitlines() if rows else [])
    for photo in paths:
        if not re.fullmatch(r'[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(?:jpg|png|webp)',photo) or photo.split('/')[0] not in owned:
            raise RuntimeError('Non-owned Storage path refused')
        owner=sql(f"select owner_id from storage.objects where bucket_id='recipe-photos' and name='{photo}';")
        if owner and owner != photo.split('/')[0]:
            raise RuntimeError('Storage owner mismatch')
    queued_count=0
    for photo in paths:
        present=sql(f"select count(*) from storage.objects where bucket_id='recipe-photos' and name='{photo}';") == '1'
        active=sql(f"select count(*) from public.recipes where hero_image_path='{photo}';") == '1'
        queued=sql(f"select count(*) from private.storage_cleanup_jobs where bucket_id='recipe-photos' and object_name='{photo}';") == '1'
        if present and ((active and queued) or (not active and not queued)):
            raise RuntimeError('Photo reference/cleanup queue invariant failed before teardown')
        queued_count += int(present and queued)
    print(f'PASS: inspected {len(paths)} fixture paths; {queued_count} stored unreferenced photos queued; active photos not queued')
    if paths:
        request=Request(status['API_URL']+'/storage/v1/object/recipe-photos',method='DELETE',data=json.dumps({'prefixes':sorted(paths)}).encode(),headers={'apikey':token,'Authorization':'Bearer '+token,'Content-Type':'application/json'})
        with urlopen(request,timeout=20) as response:
            if response.status != 200:
                raise RuntimeError('Storage fixture deletion failed')
    avatar_paths=set(data.get('avatars',[]))
    for uid in owned:
        rows=sql(f"select name from storage.objects where bucket_id='profile-avatars' and split_part(name,'/',1)='{uid}';")
        avatar_paths.update(rows.splitlines() if rows else [])
    for avatar in avatar_paths:
        if not re.fullmatch(r'[0-9a-f-]{36}/[0-9a-f-]{36}\.(?:jpg|png|webp)',avatar) or avatar.split('/')[0] not in owned:
            raise RuntimeError('Non-owned avatar path refused')
        owner=sql(f"select owner_id from storage.objects where bucket_id='profile-avatars' and name='{avatar}';")
        if owner and owner != avatar.split('/')[0]:
            raise RuntimeError('Avatar owner mismatch')
    if avatar_paths:
        request=Request(status['API_URL']+'/storage/v1/object/profile-avatars',method='DELETE',data=json.dumps({'prefixes':sorted(avatar_paths)}).encode(),headers={'apikey':token,'Authorization':'Bearer '+token,'Content-Type':'application/json'})
        with urlopen(request,timeout=20) as response:
            if response.status != 200:
                raise RuntimeError('Avatar fixture deletion failed')
    for uid in owned:
        sql(f"delete from private.storage_cleanup_jobs where bucket_id in ('recipe-photos','profile-avatars') and split_part(object_name,'/',1)='{uid}'; delete from auth.users where id='{uid}'::uuid;")
        if sql(f"select count(*) from auth.users where id='{uid}'::uuid;") != '0':
            raise RuntimeError('Fixture account cleanup incomplete')
        if sql(f"select count(*) from storage.objects where bucket_id='recipe-photos' and split_part(name,'/',1)='{uid}';") != '0':
            raise RuntimeError('Fixture objects remain')
        if sql(f"select count(*) from storage.objects where bucket_id='profile-avatars' and split_part(name,'/',1)='{uid}';") != '0':
            raise RuntimeError('Fixture avatars remain')
    print(f'PASS: removed {len(owned)} verified local fixture accounts, {len(paths)} recipe photos and {len(avatar_paths)} avatars via trusted Storage API; no production worker claimed')

if __name__ == '__main__':
    main()
