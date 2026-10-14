"""Trusted host trigger of the actual local Edge worker; no mobile secrets."""
import json
import os
from pathlib import Path
import subprocess
from urllib.request import Request,urlopen

root=Path(__file__).resolve().parents[1]
status=json.loads(subprocess.run([str(root/'.tooling/supabase/supabase.exe'),'status','-o','json'],cwd=root,
    env=dict(os.environ,DO_NOT_TRACK='1'),capture_output=True,text=True,check=True).stdout)
if status['API_URL'].rstrip('/')!='http://127.0.0.1:54321':raise SystemExit('Isolated local project required')
secret=(root/'.tooling/phase08-functions.env').read_text().strip().split('=',1)[1]
request=Request(status['API_URL']+'/functions/v1/cleanup-storage',data=b'{}',method='POST',headers={
    'apikey':status['ANON_KEY'],'x-mixtick-worker':secret,'Content-Type':'application/json'})
with urlopen(request,timeout=90) as response:
    result=json.load(response)
print(json.dumps(result))
