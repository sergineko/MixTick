"""Read-only Git/baseline and secret-pattern audit, output paths/counts only."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]
def git(*args):return subprocess.run(['git',*args],cwd=ROOT,capture_output=True,text=True,check=True).stdout
baseline=json.loads((ROOT/'.tooling/phase08-baseline/files.json').read_text('utf-8-sig'))
changed=[];missing=[]
for entry in baseline:
    path=ROOT/entry['path']
    if not path.exists():missing.append(entry['path'])
    elif hashlib.sha256(path.read_bytes()).hexdigest().upper()!=entry['sha256'].upper():changed.append(entry['path'])
allowed={'README.md','docs/PROGRESS.md','android/app/build.gradle.kts','supabase/config.toml',
 'lib/app/localization/app_es.arb','lib/app/localization/generated/app_localizations.dart',
 'lib/app/localization/generated/app_localizations_es.dart','lib/app/router.dart','lib/core/config/app_config.dart',
 'lib/features/profile/data/supabase_profile_repository.dart','lib/features/profile/presentation/profile_page.dart',
 'lib/features/profile/presentation/profile_providers.dart'}
unexpected=sorted(set(changed)-allowed)
untracked=git('ls-files','--others','--exclude-standard').splitlines()
files=sorted(set(changed+untracked))
patterns={'jwt':re.compile(rb'eyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}'),
 'secret_key':re.compile(rb'sb_secret_[A-Za-z0-9_-]{16,}'),
 'private_key':re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')}
hits=[];oversized=[]
for name in files:
    path=ROOT/name
    if not path.is_file():continue
    data=path.read_bytes()
    if len(data)>50*1024*1024:oversized.append(name)
    if path.suffix.lower() in ('.png','.jpg','.jpeg','.webp'):continue
    for label,pattern in patterns.items():
        if pattern.search(data):hits.append({'path':name,'pattern':label})
protected=[e for e in baseline if e['path'].startswith(('supabase/migrations/','supabase/tests/','test/','test_support/','integration_test/','docs/reports/'))]
assert not missing and not unexpected and not hits and not oversized,'Audit failed; inspect path-only evidence'
head=git('rev-parse','HEAD').strip()
assert head=='2e126f04112b93e2005b6c4b414ae965e9d3dd9f','Unexpected commit since approved baseline'
assert not git('diff','--cached','--name-only').strip(),'Staged content not authorized'
result={'status':'PASS','baseline_files':len(baseline),'historical_protected_files':len(protected),
 'historical_changed':[e['path'] for e in protected if e['path'] in changed],
 'head':head,'staged_files':0,'unexpected_changes':unexpected,'missing':missing,
 'secret_pattern_hits':hits,'oversized_files':oversized,'modified_tracked':changed,
 'new_files':untracked,'scope':'Tracked baseline plus Git-visible new files; ignored tooling/caches intentionally excluded; pattern scan is not a formal secret audit'}
assert not result['historical_changed'],'Historical files changed'
(ROOT/'docs/reports/phase08/evidence/workspace-audit.json').write_text(json.dumps(result,indent=2))
print(f'PASS: {len(baseline)} baseline files; {len(protected)} historical code/tests/evidence unchanged; no staged files/commits; no credential-pattern hits or >50MiB files')
