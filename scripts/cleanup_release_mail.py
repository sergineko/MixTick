"""Remove only the exact native recovery fixture's local Mailpit messages."""
import json
from pathlib import Path
import re
from urllib.request import Request,urlopen

root=Path(__file__).resolve().parents[1]
log=(root/'.tooling/native-restore-private.txt').read_text('utf-8-sig',errors='replace')
owned=set(re.findall(r'MIXTICK_RECOVERY_READY:(mixtick-native-[0-9a-f]{1,8}@example\.test)',log))
if len(owned)!=1:raise RuntimeError('Exact owned native recovery identity required')
base='http://127.0.0.1:54324'
with urlopen(base+'/api/v1/messages',timeout=10) as response:messages=json.load(response)
ids=[]
for message in messages['messages']:
    recipients={target['Address'] for target in message['To']}
    if recipients and recipients<=owned:ids.append(message['ID'])
if ids:
    request=Request(base+'/api/v1/messages',method='DELETE',data=json.dumps({'IDs':ids}).encode(),headers={'Content-Type':'application/json'})
    with urlopen(request,timeout=10) as response:
        if response.status not in (200,204):raise RuntimeError('Scoped Mailpit teardown failed')
with urlopen(base+'/api/v1/messages',timeout=10) as response:remaining=json.load(response)['total']
result={'status':'PASS','scoped_native_messages_removed':len(ids),'remaining_messages':remaining,
 'scope':'Exact recipient from current native recovery marker only; no credential, callback or email in evidence'}
(root/'docs/reports/phase08/evidence/mailpit-cleanup-final.json').write_text(json.dumps(result,indent=2))
assert remaining==0,'Unowned messages remain; not removed'
print(json.dumps(result))
