"""Scoped Phase08 host teardown, never product/perms evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.error import HTTPError
from urllib.request import Request,urlopen
import uuid

ROOT=Path(__file__).resolve().parents[1]
def sql(q):
    return subprocess.run(['docker','exec','-i','supabase_db_mixtick-phase02','psql','-U','postgres','-d','postgres','-Atq','-v','ON_ERROR_STOP=1'],input=q,capture_output=True,text=True,check=True).stdout.strip()
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--fixtures',required=True);args=parser.parse_args()
    path=(ROOT/args.fixtures).resolve()
    if path.parent!=(ROOT/'.tooling').resolve():raise SystemExit('Ignored fixture manifest required')
    data=json.loads(path.read_text('utf-8-sig'))
    users={str(uuid.UUID(u['id'])):u['email'] for u in data['users']}
    status=json.loads(subprocess.run([str(ROOT/'.tooling/supabase/supabase.exe'),'status','-o','json'],cwd=ROOT,env=dict(os.environ,DO_NOT_TRACK='1'),capture_output=True,text=True,check=True).stdout)
    if status['API_URL'].rstrip('/')!='http://127.0.0.1:54321':raise SystemExit('Local only')
    def admin(method,route,body):
        req=Request(status['API_URL']+route,method=method,data=json.dumps(body).encode(),headers={'apikey':status['SERVICE_ROLE_KEY'],'Authorization':'Bearer '+status['SERVICE_ROLE_KEY'],'Content-Type':'application/json'})
        try:
            with urlopen(req,timeout=20) as r:return r.status
        except HTTPError as e:return e.code
    for uid,email in users.items():
        if not re.fullmatch(r'mixtick-p8-(?:native-)?[0-9a-f]{10}-[a-e]@example\.test',email):raise RuntimeError('Unexpected fixture email')
        if sql(f"select email from auth.users where id='{uid}';") not in ('',email):raise RuntimeError('Fixture identity mismatch')
        objects={}
        for bucket in ('recipe-photos','profile-avatars'):
            paths=sql(f"select name from storage.objects where bucket_id='{bucket}' and owner_id='{uid}';").splitlines()
            if any(p.split('/')[0]!=uid for p in paths):raise RuntimeError('Crossed path refused')
            objects[bucket]=paths
        # Withdraw references before physical host teardown; preserve RLS and
        # the active-image protection, rather than weakening either for tests.
        sql(f"delete from private.moderation_actions where operator_id='{uid}'; delete from public.profiles where user_id='{uid}';")
        for bucket,paths in objects.items():
            if paths and admin('DELETE','/storage/v1/object/'+bucket,{'prefixes':paths})!=200:raise RuntimeError('Fixture Storage cleanup failed')
        if admin('DELETE','/auth/v1/admin/users/'+uid,{'should_soft_delete':False}) not in (200,204,404):raise RuntimeError('Fixture Auth cleanup failed')
        fingerprint=hashlib.sha256(uid.encode()).hexdigest()
        sql(f"delete from private.storage_cleanup_jobs where split_part(object_name,'/',1)='{uid}'; delete from private.account_deletions where actor_hash='{fingerprint}';")
    print(f'PASS: scoped host teardown of {len(users)} verified Phase08 identities; no product worker/account claim')
if __name__=='__main__':main()
