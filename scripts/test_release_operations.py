"""Real local Edge/Auth/PostgREST/Storage checks. Never run against remote.

Controlled SQL advances only fixture deadlines/leases or creates poison jobs.
Storage/Auth outages stop only this project's named service, always restarted.
Privileged host setup/teardown is separate from product and permission proof.
"""
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen
import uuid

ROOT = Path(__file__).resolve().parents[1]
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jEukAAAAASUVORK5CYII=')

class Suite:
    def __init__(self, label):
        status = json.loads(subprocess.run([str(ROOT/'.tooling/supabase/supabase.exe'),'status','-o','json'],cwd=ROOT,env=dict(os.environ,DO_NOT_TRACK='1'),capture_output=True,text=True,check=True).stdout)
        if status['API_URL'].rstrip('/') != 'http://127.0.0.1:54321': raise RuntimeError('Local only')
        self.base=status['API_URL'].rstrip('/'); self.public=status['ANON_KEY']; self.admin=status['SERVICE_ROLE_KEY']
        self.worker_secret=(ROOT/'.tooling/phase08-functions.env').read_text().strip().split('=',1)[1]
        self.users={}; self.photos=[]; self.jobs=[]; self.requests=[]; self.results=[]
        self.suffix=uuid.uuid4().hex[:10]
        self.evidence=ROOT/f'docs/reports/phase08/evidence/operations-{label}'
        self.evidence.mkdir(parents=True,exist_ok=False)
        if self.sql('select count(*) from auth.users;') != '0': raise RuntimeError('Empty dedicated fixture project required')
    def sql(self,q):
        run=subprocess.run(['docker','exec','-i','supabase_db_mixtick-phase02','psql','-U','postgres','-d','postgres','-Atq','-v','ON_ERROR_STOP=1'],input=q,capture_output=True,text=True)
        if run.returncode: raise AssertionError('Fixture/introspection SQL failed; no credentials logged')
        return run.stdout.strip()
    def http(self,method,path,user=None,body=None,raw=None,worker=False):
        token=self.admin if user=='admin' else self.users[user]['token'] if user else self.public
        headers={'apikey':self.admin if user=='admin' else self.public,'Authorization':'Bearer '+token,'Content-Type':'image/png' if raw is not None else 'application/json'}
        if worker: headers['x-mixtick-worker']=self.worker_secret
        req=Request(self.base+path,data=raw if raw is not None else json.dumps(body).encode() if body is not None else None,method=method,headers=headers)
        try:
            with urlopen(req,timeout=25) as response: code=response.status; data=response.read()
        except HTTPError as error: code=error.code;data=error.read()
        try: data=json.loads(data) if data else None
        except (ValueError,UnicodeDecodeError): pass
        return code,data
    def expect_http(self,method,path,user=None,body=None,raw=None,codes=(200,204),worker=False):
        code,data=self.http(method,path,user,body,raw,worker)
        if code not in codes:
            diagnostic={key:data[key] for key in ('code','statusCode','error','message') if isinstance(data,dict) and key in data}
            safe=re.sub(r'eyJ[\w-]+\.[\w-]+\.[\w-]+|[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', '[REDACTED]',json.dumps(diagnostic))
            raise AssertionError(f'Unexpected HTTP {code}; expected {codes}; diagnostic {safe}')
        return data
    def rpc(self,user,name,body=None): return self.expect_http('POST','/rest/v1/rpc/'+name,user,body or {})
    def manifest(self):
        (ROOT/'.tooling/phase08-fixtures.json').write_text(json.dumps({'users':[{'id':u['id'],'email':u['email']} for u in self.users.values()],'jobs':self.jobs,'requests':self.requests}),encoding='utf-8')
    def signup(self,letter):
        password='P8-'+uuid.uuid4().hex+'!'; email=f'mixtick-p8-{self.suffix}-{letter}@example.test'
        data=self.expect_http('POST','/auth/v1/signup',body={'email':email,'password':password})
        u={'id':str(uuid.UUID(data['user']['id'])),'token':data['access_token'],'refresh':data['refresh_token'],'email':email,'password':password,'username':f'p8_{self.suffix}_{letter}'}
        self.users[letter]=u;self.manifest()
        self.expect_http('POST','/rest/v1/profiles',letter,{'username':u['username'],'display_name':'Auditoría '+letter.upper()},codes=(201,))
    def recipe(self,user,title='Fixture privada'):
        return self.rpc(user,'create_recipe_once',{'p_request_id':str(uuid.uuid4()),'p_recipe':{'title':title,'category':'Auditoría','servings':1},'p_ingredients':[{'ingredient_id':'10000000-0000-4000-8000-000000000004','quantity':1,'unit':'ud'}],'p_steps':['Paso controlado']})
    def row(self,user,table,key,value):
        rows=self.expect_http('GET',f'/rest/v1/{table}?{key}=eq.{value}&select=*',user)
        return rows[0] if rows else None
    def photo(self,user,recipe=None,bucket='recipe-photos'):
        path=self.users[user]['id']+'/'+(recipe+'/' if recipe else '')+str(uuid.uuid4())+'.png'
        self.expect_http('POST','/storage/v1/object/'+bucket+'/'+path,user,raw=PNG)
        self.photos.append((bucket,path)); return path
    def link(self,user,recipe,path):
        row=self.row(user,'recipes','id',recipe)
        return self.rpc(user,'set_recipe_photo',{'p_recipe_id':recipe,'p_expected_version':row['version'],'p_path':path})
    def due(self,path): self.sql(f"update private.storage_cleanup_jobs set not_before=clock_timestamp()-interval '1 second' where object_name='{path}';")
    def state(self,path): return self.sql(f"select state from private.storage_cleanup_jobs where object_name='{path}';")
    def exists(self,bucket,path):
        return self.http('GET','/storage/v1/object/authenticated/'+bucket+'/'+path,'admin')[0]==200
    def physical(self,bucket,path):
        # Read actual file backend, not just metadata or an inaccessible JWT URL.
        run=subprocess.run(['docker','exec','supabase_storage_mixtick-phase02','find','/mnt','-type','f'],capture_output=True,text=True,check=True)
        return sum('/'+bucket+'/'+path in name for name in run.stdout.splitlines())
    def worker(self): return self.expect_http('POST','/functions/v1/cleanup-storage',body={},worker=True)
    def case(self,id,title,fn):
        started=time.perf_counter()
        try: fn(); result={'id':id,'title':title,'status':'PASS','ms':round((time.perf_counter()-started)*1000,3)}
        except Exception as error:
            result={'id':id,'title':title,'status':'FAIL','failure_type':type(error).__name__}
            self.results.append(result); self.save(); print(f'{id}: FAIL ({type(error).__name__}; no sensitive payload)',flush=True); raise
        self.results.append(result);self.save(); print(f'{id}: PASS — {title}',flush=True)
    def save(self): (self.evidence/'results.json').write_text(json.dumps(self.results,ensure_ascii=False,indent=2),encoding='utf-8')
    def assert_removed(self,bucket,path):
        assert not self.exists(bucket,path),'Object still served'
        assert self.physical(bucket,path)==0,'Physical fixture file still exists'
        assert self.state(path)=='done','Removal not confirmed in durable queue'
    def stop(self,service):
        subprocess.run(['docker','stop','supabase_'+service+'_mixtick-phase02'],capture_output=True,check=True)
    def start(self,service):
        subprocess.run(['docker','start','supabase_'+service+'_mixtick-phase02'],capture_output=True,check=True)
        deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            state=subprocess.run(['docker','inspect','--format','{{.State.Health.Status}}','supabase_'+service+'_mixtick-phase02'],capture_output=True,text=True).stdout.strip()
            if state=='healthy': return
            time.sleep(.25)
        raise AssertionError('Named local service did not recover')
    def delete_request(self,user,**changes):
        request_id=str(uuid.uuid4());self.requests.append(request_id);self.manifest()
        payload={'password':self.users[user]['password'],'confirmation':'ELIMINAR','delete_owned_lists':True,'request_id':request_id};payload.update(changes)
        return self.http('POST','/functions/v1/delete-account',user,payload)
    def cleanup(self):
        # Fixture teardown only, never counted as product worker/account evidence.
        for service in ('storage','auth'):
            state=subprocess.run(['docker','inspect','--format','{{.State.Running}}','supabase_'+service+'_mixtick-phase02'],capture_output=True,text=True).stdout.strip()
            if state=='false': self.start(service)
        for u in self.users.values():
            assert re.fullmatch(r'mixtick-p8-[0-9a-f]{10}-[a-e]@example\.test',u['email'])
            actual=self.sql(f"select email from auth.users where id='{u['id']}';")
            assert actual in ('',u['email']),'Fixture identity mismatch'
            for bucket in ('recipe-photos','profile-avatars'):
                paths=self.sql(f"select name from storage.objects where bucket_id='{bucket}' and owner_id='{u['id']}';").splitlines()
                for path in paths: assert path.split('/')[0]==u['id'],'Foreign path refused'
                if paths: self.expect_http('DELETE','/storage/v1/object/'+bucket,'admin',{'prefixes':paths})
            self.sql(f"delete from private.moderation_actions where operator_id='{u['id']}'; delete from private.storage_cleanup_jobs where split_part(object_name,'/',1)='{u['id']}';")
            self.http('DELETE','/auth/v1/admin/users/'+u['id'],'admin',{'should_soft_delete':False})
            self.sql(f"delete from private.account_deletions where actor_hash='{hashlib.sha256(u['id'].encode()).hexdigest()}';")
        if self.jobs: self.sql('delete from private.storage_cleanup_jobs where id in ('+','.join("'"+str(uuid.UUID(j))+"'::uuid" for j in self.jobs)+');')
        assert self.sql('select count(*) from auth.users;')=='0'
        self.manifest(); print('PASS: scoped fixture teardown completed; not product evidence',flush=True)

def run(s):
    for letter in 'abcd':s.signup(letter)
    a=s.users['a'];b=s.users['b'];c=s.users['c'];d=s.users['d']
    recipe=s.recipe('a'); foreign=s.recipe('b')
    foreign_photo=s.photo('b',foreign);s.link('b',foreign,foreign_photo)
    def auth_negative():
        assert s.http('POST','/functions/v1/cleanup-storage',body={})[0]==401
        for name,body in [('claim_storage_cleanup',{}),('begin_account_deletion',{'p_actor_id':b['id'],'p_request_id':str(uuid.uuid4()),'p_delete_owned_lists':True})]:
            assert s.http('POST','/rest/v1/rpc/'+name,'a',body)[0] in (401,403)
    s.case('S01','ordinary user/anon cannot consume jobs or invoke administrative deletion',auth_negative)
    orphan=s.photo('a',recipe)
    def queued():
        assert s.state(orphan)=='queued';assert s.exists('recipe-photos',orphan);assert s.physical('recipe-photos',orphan)>0
        s.worker();assert s.exists('recipe-photos',orphan)
    s.case('F11','queued job is physically present; pre-grace worker preserves it',queued)
    def remove_grace():s.due(orphan);s.worker();s.assert_removed('recipe-photos',orphan)
    s.case('F01','eligible unreferenced photo physically removed through server worker',remove_grace)
    active=s.photo('a',recipe);s.link('a',recipe,active)
    def preserve():
        s.sql(f"insert into private.storage_cleanup_jobs(bucket_id,object_name,not_before) values('recipe-photos','{active}',clock_timestamp());")
        s.worker();assert s.exists('recipe-photos',active);assert s.physical('recipe-photos',active)>0
    s.case('F02','current active reference survives an eligible poison job',preserve)
    def reappeared():
        s.link('a',recipe,None);s.due(active);s.link('a',recipe,active);s.worker();assert s.exists('recipe-photos',active)
        candidate=s.photo('a',recipe);s.due(candidate)
        claim=s.rpc('admin','claim_storage_cleanup',{'p_limit':1})[0]
        assert claim['path']==candidate
        row=s.row('a','recipes','id',recipe)
        assert s.http('POST','/rest/v1/rpc/set_recipe_photo','a',{'p_recipe_id':recipe,'p_expected_version':row['version'],'p_path':candidate})[0]==409
        s.sql(f"update private.storage_cleanup_jobs set lease_until=clock_timestamp()-interval '1 second' where id='{claim['id']}';")
        s.worker();s.assert_removed('recipe-photos',candidate)
    s.case('F03','reappearing reference preserved; link after committed deletion fence rejected',reappeared)
    replacement=s.photo('a',recipe)
    def replace():s.link('a',recipe,replacement);s.due(active);s.worker();s.assert_removed('recipe-photos',active);assert s.exists('recipe-photos',replacement)
    s.case('F04','replacement retires old physical file and preserves the new one',replace)
    deleted=s.recipe('a','Receta a borrar');deleted_photo=s.photo('a',deleted);s.link('a',deleted,deleted_photo)
    def delete_recipe():
        row=s.row('a','recipes','id',deleted);s.rpc('a','delete_recipe_versioned',{'p_recipe_id':deleted,'p_expected_version':row['version']});s.due(deleted_photo);s.worker();s.assert_removed('recipe-photos',deleted_photo)
    s.case('F05','recipe deletion queues and physically removes its folder image',delete_recipe)
    avatar=s.photo('a',bucket='profile-avatars')
    def avatar_remove():
        s.expect_http('PATCH','/rest/v1/profiles?user_id=eq.'+a['id'],'a',{'avatar_path':avatar})
        s.expect_http('PATCH','/rest/v1/profiles?user_id=eq.'+a['id'],'a',{'avatar_path':None})
        s.due(avatar);s.worker();s.assert_removed('profile-avatars',avatar)
    s.case('F06','removed avatar physically deleted by the same worker',avatar_remove)
    crash=s.photo('a',recipe)
    def crash_recovery():
        s.due(crash);claim=s.rpc('admin','claim_storage_cleanup',{'p_limit':1})[0]
        assert s.exists('recipe-photos',crash)
        s.sql(f"update private.storage_cleanup_jobs set lease_until=clock_timestamp()-interval '1 second' where id='{claim['id']}';")
        s.worker();s.assert_removed('recipe-photos',crash)
        s.rpc('admin','finish_storage_cleanup',{'p_id':claim['id'],'p_claim_id':claim['claim_id'],'p_removed':False})
        assert s.state(crash)=='done'
    s.case('F07','expired abandoned lease recovered; stale completion cannot overwrite newer result',crash_recovery)
    concurrent=s.photo('a',recipe)
    def concurrency():
        s.due(concurrent)
        with ThreadPoolExecutor(max_workers=2) as pool:claims=list(pool.map(lambda _:s.rpc('admin','claim_storage_cleanup',{'p_limit':1}),range(2)))
        claimed=[j for batch in claims for j in batch];assert len(claimed)==1
        s.sql(f"update private.storage_cleanup_jobs set lease_until=clock_timestamp()-interval '1 second' where object_name='{concurrent}';")
        s.worker();s.assert_removed('recipe-photos',concurrent)
    s.case('F08','independent concurrent claimers obtain exactly one lease',concurrency)
    mismatch=s.photo('a',recipe)
    def poison():
        bad=str(uuid.uuid4());s.jobs.append(bad);s.manifest()
        s.sql(f"insert into private.storage_cleanup_jobs(id,bucket_id,object_name,owner_id,not_before) values('{bad}','recipe-photos','../p8-{s.suffix}.png','{a['id']}',clock_timestamp());")
        s.sql(f"update private.storage_cleanup_jobs set owner_id='{b['id']}',not_before=clock_timestamp() where object_name='{mismatch}';")
        s.worker();assert s.sql(f"select error_code from private.storage_cleanup_jobs where id='{bad}';")=='invalid_path'
        assert s.state(mismatch)=='dead';assert s.exists('recipe-photos',mismatch);assert s.exists('recipe-photos',foreign_photo)
        s.sql(f"update private.storage_cleanup_jobs set owner_id='{a['id']}',state='queued',not_before=clock_timestamp() where object_name='{mismatch}';")
        s.worker();s.assert_removed('recipe-photos',mismatch)
    s.case('F09','path traversal and forged queue owner fail closed, without crossed removal',poison)
    outage=s.photo('a',recipe)
    def storage_outage():
        s.due(outage);s.stop('storage')
        try:
            for _ in range(5):
                result=s.worker();assert result['storage']['retried']==1
                s.due(outage)
            assert s.state(outage)=='dead'
            assert s.sql(f"select attempts from private.storage_cleanup_jobs where object_name='{outage}';")=='5'
        finally:s.start('storage')
        assert s.exists('recipe-photos',outage)
        # Explicit trusted operator requeue after fixing outage. Keep the fence.
        s.sql(f"update private.storage_cleanup_jobs set state='queued',attempts=0,not_before=clock_timestamp() where object_name='{outage}' and state='dead' and error_code='storage_failure';")
        s.worker();s.assert_removed('recipe-photos',outage)
    s.case('F10','real Storage outage retries five times, dead-letters, then explicitly recovers',storage_outage)
    missing=s.photo('a',recipe)
    def already_missing():
        s.expect_http('DELETE','/storage/v1/object/recipe-photos','a',{'prefixes':[missing]});s.due(missing);s.worker();s.assert_removed('recipe-photos',missing)
    s.case('F07b','already absent object completes idempotently without losing the job',already_missing)
    s.case('F12','unrelated active B file survives every worker scenario',lambda: (s.exists('recipe-photos',foreign_photo) and s.physical('recipe-photos',foreign_photo)>0) or (_ for _ in []).throw(AssertionError('Foreign resource changed')))

    owned=s.recipe('d','Datos privados a eliminar');owned_photo=s.photo('d',owned);s.link('d',owned,owned_photo)
    own_avatar=s.photo('d',bucket='profile-avatars');s.expect_http('PATCH','/rest/v1/profiles?user_id=eq.'+d['id'],'d',{'avatar_path':own_avatar})
    own_list=s.rpc('d','create_shopping_list_once',{'p_request_id':str(uuid.uuid4()),'p_title':'Lista de D compartida'})
    item=s.rpc('d','add_shopping_item_once',{'p_list_id':own_list,'p_request_id':str(uuid.uuid4()),'p_item':{'name':'Producto compartido'}})
    invitation=s.rpc('d','invite_to_list',{'p_list_id':own_list,'p_username':b['username']});s.rpc('b','respond_to_invitation',{'p_invitation_id':invitation,'p_accept':True})
    foreign_list=s.rpc('a','create_shopping_list_once',{'p_request_id':str(uuid.uuid4()),'p_title':'Lista ajena que se conserva'})
    old=s.rpc('a','invite_to_list',{'p_list_id':foreign_list,'p_username':d['username']});s.rpc('d','respond_to_invitation',{'p_invitation_id':old,'p_accept':True})
    def deletion_negative():
        assert s.delete_request('a',user_id=d['id'])[0]==400
        assert s.delete_request('d',password='wrong-password')[0]==403
        assert s.delete_request('d',delete_owned_lists=False)[0]==400
        assert s.row('d','recipes','id',owned) is not None
    s.case('D02','foreign UID, wrong password and unconfirmed owned-list policy rejected',deletion_negative)
    def accepted():
        code,data=s.delete_request('d');assert code==202 and data['accepted'] is True
        assert s.sql(f"select count(*) from private.account_deletions where actor_id='{d['id']}';")=='1'
    s.case('D01a','authenticated reauthentication accepts one durable self-deletion request',accepted)
    s.case('D04','private recipe and profile withdrawn atomically before physical cleanup',lambda: (s.row('d','recipes','id',owned) is None and s.row('d','profiles','user_id',d['id']) is None) or (_ for _ in []).throw(AssertionError()))
    def permissions_after():
        assert s.rpc('d','shopping_list_snapshot',{'p_list_id':foreign_list}) is None
        assert s.http('POST','/rest/v1/rpc/respond_to_invitation','d',{'p_invitation_id':old,'p_accept':True})[0] in (401,403)
        assert s.http('POST','/rest/v1/profiles','d',{'username':'resurrected_p8','display_name':'No'})[0] in (401,403)
        assert s.expect_http('GET','/rest/v1/ingredients?select=id','d')==[]
    s.case('D06-D07','old JWT loses memberships/invitations and cannot recreate a profile',permissions_after)
    s.case('D08','owned shared list/products removed while foreign list remains',lambda: (s.row('b','shopping_lists','id',own_list) is None and s.row('b','shopping_items','id',item) is None and s.row('a','shopping_lists','id',foreign_list) is not None) or (_ for _ in []).throw(AssertionError()))
    def interrupted_auth():
        s.stop('auth')
        try:
            result=s.worker();assert result['storage']['removed']==2;assert result['accounts']['retried']==1
            assert s.sql(f"select state from private.account_deletions where actor_id='{d['id']}';")=='queued'
            assert s.physical('recipe-photos',owned_photo)==0 and s.physical('profile-avatars',own_avatar)==0
        finally:s.start('auth')
        s.sql(f"update private.account_deletions set not_before=clock_timestamp() where actor_id='{d['id']}';")
        result=s.worker();assert result['accounts']['completed']==1
        assert s.sql(f"select count(*) from auth.users where id='{d['id']}';")=='0'
    s.case('D10','real Auth outage after acceptance reconciles without crossed deletion',interrupted_auth)
    s.case('D05','recipe photograph and avatar physically absent after account worker',lambda: (s.physical('recipe-photos',owned_photo)==0 and s.physical('profile-avatars',own_avatar)==0 and not s.exists('recipe-photos',owned_photo) and not s.exists('profile-avatars',own_avatar)) or (_ for _ in []).throw(AssertionError()))
    def sessions():
        assert s.http('POST','/auth/v1/token?grant_type=refresh_token',body={'refresh_token':d['refresh']})[0] in (400,401)
        assert s.http('GET','/auth/v1/user','d')[0] in (401,403)
        assert s.expect_http('GET','/rest/v1/recipes?select=id','d')==[]
    s.case('D03','refresh and live Auth validation fail; unexpired JWT cannot read app rows',sessions)
    s.case('D09','B identity/private content and other owned list untouched',lambda: (s.sql(f"select count(*) from auth.users where id='{b['id']}';")=='1' and s.row('b','recipes','id',foreign) is not None and s.exists('recipe-photos',foreign_photo)) or (_ for _ in []).throw(AssertionError()))
    def personal_data():
        for table,column in [('recipes','author_id'),('recipe_comments','author_id'),('recipe_likes','user_id'),('recipe_saves','user_id'),('shopping_lists','owner_id'),('shopping_list_members','user_id'),('content_reports','reporter_id')]:
            assert s.sql(f"select count(*) from public.{table} where {column}='{d['id']}';")=='0'
        assert s.sql(f"select count(*) from private.account_deletions where actor_id='{d['id']}';")=='0'
    s.case('D11','personal product rows removed; only private minimized thirty-day operation trace remains',personal_data)
    s.case('D01','Auth identity permanently removed by product server operation',lambda: s.sql(f"select count(*) from auth.users where id='{d['id']}';")=='0' or (_ for _ in []).throw(AssertionError()))

    def concurrent_upload_deletion():
        s.signup('e');user=s.users['e'];rid=s.recipe('e','Subida concurrente con retirada de cuenta')
        path=user['id']+'/'+rid+'/'+str(uuid.uuid4())+'.png'
        with ThreadPoolExecutor(max_workers=2) as pool:
            upload=pool.submit(s.http,'POST','/storage/v1/object/recipe-photos/'+path,'e',None,PNG)
            deletion=pool.submit(s.delete_request,'e')
            upload_code=upload.result()[0];delete_code=deletion.result()[0]
        assert upload_code in (200,400,401,403) and delete_code==202
        for _ in range(3):s.worker()
        assert s.sql(f"select count(*) from auth.users where id='{user['id']}';")=='0'
        assert not s.exists('recipe-photos',path) and s.physical('recipe-photos',path)==0
    s.case('D13','concurrent real upload and deletion leave no orphan or revived account',concurrent_upload_deletion)

    # Operator role is trusted local fixture setup, never mutable Auth user data.
    s.sql(f"insert into private.moderation_operators(user_id) values('{c['id']}');")
    private_report=s.rpc('a','submit_report',{'p_target_type':'recipe','p_target_id':recipe,'p_reason':'Informe privado controlado de prueba'})
    row=s.row('a','recipes','id',recipe);s.rpc('a','set_recipe_visibility',{'p_recipe_id':recipe,'p_expected_version':row['version'],'p_visibility':'public'})
    report=s.rpc('b','submit_report',{'p_target_type':'recipe','p_target_id':recipe,'p_reason':'Contenido público controlado a revisar'})
    secret_recipe=s.recipe('a','Título privado que no debe ver el operador')
    secret_report=s.rpc('a','submit_report',{'p_target_type':'recipe','p_target_id':secret_recipe,'p_reason':'Motivo controlado sin información privada'})
    def ordinary_denied():
        s.expect_http('PUT','/auth/v1/user','b',{'data':{'moderator':True,'role':'admin'}})
        assert s.http('POST','/rest/v1/rpc/moderation_reports','b',{})[0]==403
        assert s.http('POST','/rest/v1/rpc/moderate_report','b',{'p_report_id':report,'p_expected_status':'open','p_action':'close'})[0]==403
    s.case('O01','ordinary account and forged user metadata cannot administer reports',ordinary_denied)
    def redacted():
        reports=s.rpc('c','moderation_reports',{'p_limit':20})
        target=next(r for r in reports if r['id']==secret_report)
        assert target['private_content_redacted'] is True and target['public_preview'] is None
        assert all('reporter_id' not in r and 'email' not in r for r in reports)
    s.case('O02','authorized report listing redacts private contents and reporter identity',redacted)
    def operator_console():
        environment=dict(os.environ,MIXTICK_OPS_URL=s.base,MIXTICK_OPS_PUBLIC_KEY=s.public,MIXTICK_OPS_ACCESS_TOKEN=c['token'])
        command=[os.sys.executable,str(ROOT/'scripts/moderation_cli.py')]
        listing=subprocess.run(command+['--limit','20'],env=environment,capture_output=True,text=True,check=True)
        records=json.loads(listing.stdout)
        target=next(r for r in records if r['id']==secret_report)
        assert target['public_preview'] is None and target['private_content_redacted'] is True
        acted=subprocess.run(command+['--report',private_report,'--action','review','--expected-status','open'],env=environment,capture_output=True,text=True,check=True)
        action=str(uuid.UUID(json.loads(acted.stdout)))
        assert s.sql(f"select count(*) from private.moderation_actions where id='{action}' and operator_id='{c['id']}';")=='1'
        environment['MIXTICK_OPS_ACCESS_TOKEN']=b['token']
        denied=subprocess.run(command+['--limit','20'],env=environment,capture_output=True,text=True)
        assert denied.returncode!=0 and 'HTTP 403' in denied.stderr
    s.case('O07','real operator CLI lists redacted reports, acts with audit and denies ordinary JWT',operator_console)
    def hide():
        action=s.rpc('c','moderate_report',{'p_report_id':report,'p_expected_status':'open','p_action':'hide_recipe'})
        assert s.sql(f"select count(*) from private.moderation_actions where id='{action}' and operator_id='{c['id']}';")=='1'
        assert s.row('b','recipes','id',recipe) is None
        row=s.row('a','recipes','id',recipe)
        assert s.http('POST','/rest/v1/rpc/set_recipe_visibility','a',{'p_recipe_id':recipe,'p_expected_version':row['version'],'p_visibility':'public'})[0]==403
        s.rpc('c','moderate_report',{'p_report_id':report,'p_expected_status':'closed','p_action':'restore_recipe'})
        s.rpc('a','set_recipe_visibility',{'p_recipe_id':recipe,'p_expected_version':row['version'],'p_visibility':'public'})
        assert s.row('b','recipes','id',recipe) is not None
    s.case('O03','operator action audited; author cannot bypass hide; authorized restore stays explicit',hide)
    comment=s.rpc('b','create_comment_once',{'p_id':str(uuid.uuid4()),'p_recipe_id':recipe,'p_content':'Comentario de prueba operativa'})
    comment_report=s.rpc('a','submit_report',{'p_target_type':'comment','p_target_id':comment,'p_reason':'Comentario controlado a revisar'})
    def remove_comment():
        s.rpc('c','moderate_report',{'p_report_id':comment_report,'p_expected_status':'open','p_action':'remove_comment'})
        assert s.row('b','recipe_comments','id',comment) is None
    s.case('O04','moderation removes only the reported comment and records action',remove_comment)
    profile_report=s.rpc('a','submit_report',{'p_target_type':'profile','p_target_id':b['id'],'p_reason':'Perfil de prueba para restricción'})
    def restrict():
        s.rpc('c','moderate_report',{'p_report_id':profile_report,'p_expected_status':'open','p_action':'restrict_profile'})
        assert s.row('a','profiles','user_id',b['id']) is None
        row=s.row('b','recipes','id',foreign)
        assert s.http('POST','/rest/v1/rpc/set_recipe_visibility','b',{'p_recipe_id':foreign,'p_expected_version':row['version'],'p_visibility':'public'})[0]==403
        s.rpc('c','moderate_report',{'p_report_id':profile_report,'p_expected_status':'closed','p_action':'restore_profile'})
        assert s.row('a','profiles','user_id',b['id']) is not None
    s.case('O05','reported profile restriction prevents participation; only operator can restore',restrict)
    def conflict():
        assert s.http('POST','/rest/v1/rpc/moderate_report','c',{'p_report_id':report,'p_expected_status':'open','p_action':'close'})[0]==409
        assert s.http('POST','/rest/v1/rpc/moderation_reports','c',{'p_limit':10000})[0]==400
    s.case('O06','operator state conflicts and unbounded reads rejected',conflict)
    s.case('S02','active foreign photo still intact after account deletion and moderation tests',lambda:s.exists('recipe-photos',foreign_photo) or (_ for _ in []).throw(AssertionError()))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--label',required=True);args=parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+',args.label):raise SystemExit('Safe unique evidence label required')
    suite=Suite(args.label)
    try:run(suite)
    finally:suite.cleanup();suite.save()
    print(f'PASS: {len(suite.results)} real local operation cases',flush=True)
