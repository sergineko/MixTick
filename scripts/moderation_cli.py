"""Minimal operator console. Public key + operator JWT, never service_role.

Credentials come from process environment; never pass them as CLI arguments.
Remote operation requires the separately explicit --allow-remote flag.
"""
import argparse
import json
import os
from urllib.parse import urlparse
from urllib.request import Request,urlopen
from urllib.error import HTTPError
import uuid

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--allow-remote',action='store_true')
    parser.add_argument('--limit',type=int,default=20)
    parser.add_argument('--after')
    parser.add_argument('--report')
    parser.add_argument('--action',choices=['review','close','hide_recipe','restore_recipe','remove_comment','restrict_profile','restore_profile'])
    parser.add_argument('--expected-status',choices=['open','reviewed','closed'])
    args=parser.parse_args()
    url=os.environ.get('MIXTICK_OPS_URL','').rstrip('/')
    public=os.environ.get('MIXTICK_OPS_PUBLIC_KEY',''); token=os.environ.get('MIXTICK_OPS_ACCESS_TOKEN','')
    parsed=urlparse(url)
    local=url=='http://127.0.0.1:54321'
    if not local and (not args.allow_remote or parsed.scheme!='https' or not parsed.hostname):
        raise SystemExit('Remote operation requires authorization, HTTPS and --allow-remote')
    if parsed.username or parsed.password or parsed.query or parsed.fragment or not public or not token:
        raise SystemExit('Set a public key and an authorized operator access token in the process environment')
    # Reject known administrative JWTs before making a request. Signature and
    # operator permissions remain server authority, never this local check.
    import base64
    try: role=json.loads(base64.urlsafe_b64decode(token.split('.')[1]+'==='))['role']
    except (ValueError,IndexError,KeyError):raise SystemExit('A user access token is required')
    if role!='authenticated':raise SystemExit('An end-user operator JWT is required; no admin keys')
    if args.action:
        if not args.report or not args.expected_status:raise SystemExit('Action requires report and expected status')
        name='moderate_report';body={'p_report_id':str(uuid.UUID(args.report)),'p_expected_status':args.expected_status,'p_action':args.action}
    else:
        if not 1<=args.limit<=50:raise SystemExit('Limit 1..50 required')
        name='moderation_reports';body={'p_limit':args.limit,'p_after':str(uuid.UUID(args.after)) if args.after else None}
    request=Request(url+'/rest/v1/rpc/'+name,method='POST',data=json.dumps(body).encode(),headers={'apikey':public,'Authorization':'Bearer '+token,'Content-Type':'application/json'})
    try:
        with urlopen(request,timeout=20) as response:result=json.load(response)
    except HTTPError as error:raise SystemExit(f'Operator request denied/failed: HTTP {error.code}; no credential output')
    # Output is intended only for the authenticated operator, not mobile/logs.
    print(json.dumps(result,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
