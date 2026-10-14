"""Phase08: original fixture distribution, invoker/RLS plans and repeated SQL.

Requires an empty isolated local project. No HTTP/Auth benchmark or production
claim. Fixtures and temporary helpers live in one rollback transaction.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--label", required=True)
parser.add_argument("--samples", type=int, default=30)
args = parser.parse_args()
if not re.fullmatch(r"[a-z0-9_-]+", args.label) or args.samples < 20:
    raise SystemExit("Safe label and at least 20 measured samples required")
original = (ROOT / "scripts/benchmark_matching.sql").read_text(encoding="utf-8")
fixture = original.split(r"\timing on")[0]
source = (ROOT / "supabase/migrations/20261013001000_cook_today_matching.sql").read_text(encoding="utf-8")
# For AFTER use the deployed function source, keeping 010 immutable.
source_result = subprocess.run(["docker", "exec", "supabase_db_mixtick-phase02", "psql", "-U", "postgres", "-d", "postgres", "-At", "-c",
    "select prosrc from pg_proc where oid='public.cook_today_page(uuid[],text[],text,jsonb,integer)'::regprocedure"], capture_output=True, text=True, check=True)
source = source_result.stdout
inner = source.split("return query", 1)[1].rsplit("end;", 1)[0].strip().rstrip(";")
rpc = "public.cook_today_page(p_names=>array['Huevos','Patatas'],p_mode=>'{mode}',p_after=>{cursor},p_limit=>9)"
cursors = {"exact": "null::jsonb", "near": "null::jsonb", "next": "'{\"missing\":0,\"rank\":0,\"minutes\":15,\"id\":\"70000000-0000-4000-8000-000000000014\"}'::jsonb"}
sql = fixture + """
reset role;
create function pg_temp.plan(q text) returns jsonb language plpgsql security invoker as $$
declare r record; begin
  for r in execute 'explain (analyze,buffers,format json) '||q loop return r."QUERY PLAN"::jsonb; end loop;
end $$;
create function pg_temp.sample(mode text, cursor jsonb, warm boolean, n integer) returns jsonb
language plpgsql security invoker as $$
declare started timestamptz; elapsed numeric; result jsonb;
begin
  started:=clock_timestamp();
  select jsonb_agg(jsonb_build_object('id',j->'recipe'->>'id','required',j->'required','matched',j->'matched',
    'missing',j->'missing','optional',j->'optional_matched','cursor',j->'cursor',
    'lines',(select jsonb_agg(x-'line_id' order by (x->>'sort_order')::integer)
      from jsonb_array_elements(j->'missing_ingredients') x))) into result
    from public.cook_today_page(p_names=>array['Huevos','Patatas'],p_mode=>mode,p_after=>cursor,p_limit=>9) j;
  elapsed:=extract(epoch from clock_timestamp()-started)*1000;
  if jsonb_array_length(result)<>9 then raise exception 'Expected 9 results'; end if;
  return jsonb_build_object('kind','sample','mode',case when cursor is not null then 'next' else mode end,
    'warmup',warm,'n',n,'ms',elapsed,'rows',jsonb_array_length(result),
    'result_hash',encode(extensions.digest(result::text,'sha256'),'hex'));
end $$;
set local role authenticated;
select jsonb_build_object('kind','environment','role',current_user,'rls',current_setting('row_security'),
 'server',version(),'fixture_recipes',6000,'fixture_lines',18000,'fixture_steps',6000);
"""
for label, cursor in cursors.items():
    mode = "near" if label == "near" else "exact"
    q = inner
    replacements = {"v_ids": "array['10000000-0000-4000-8000-000000000004'::uuid,'10000000-0000-4000-8000-000000000003'::uuid]", "v_free": "'{}'::text[]",
        "p_mode": f"'{mode}'", "p_after": cursor, "p_limit": "9", "v_missing": "0", "v_rank": "0", "v_minutes": "15", "v_id": "'70000000-0000-4000-8000-000000000014'::uuid"}
    for name, value in replacements.items():
        q = re.sub(rf"\b{name}\b", value, q)
    # EXPLAIN inner statement exposes operators; RPC plan measures actual call.
    for plan_kind, statement in [("inner", q), ("rpc", "select * from " + rpc.format(mode=mode, cursor=cursor))]:
        sql += f"select jsonb_build_object('kind','plan','mode','{label}','type','{plan_kind}','plan',pg_temp.plan($query${statement}$query$));\n"
    for n in range(2 + args.samples):
        sql += f"select pg_temp.sample('{mode}',{cursor},{str(n < 2).lower()},{n});\n"
sql += "rollback;\nselect jsonb_build_object('kind','cleanup','auth',(select count(*) from auth.users),'recipes',(select count(*) from public.recipes));\n"
output = ROOT / f"docs/reports/phase08/evidence/benchmark-{args.label}"
output.mkdir(parents=True, exist_ok=True)
(output / "query.sql").write_text(sql, encoding="utf-8")
run = subprocess.run(["docker", "exec", "-i", "supabase_db_mixtick-phase02", "psql", "-U", "postgres", "-d", "postgres", "-Atq", "-v", "ON_ERROR_STOP=1"], input=sql, capture_output=True, text=True)
(output / "stderr.txt").write_text(run.stderr, encoding="utf-8")
(output / "stdout.txt").write_text(run.stdout, encoding="utf-8")
if run.returncode:
    raise SystemExit(f"FAIL: benchmark exit={run.returncode}; see redacted local evidence")
records = [json.loads(line) for line in run.stdout.splitlines() if line.startswith('{')]
summary = {"status": "PASS", "exit_code": run.returncode, "original_fixture_sha256": hashlib.sha256(original.encode()).hexdigest(), "samples_per_mode": args.samples, "warmups_per_mode": 2, "metrics": {}}
for label in cursors:
    values = sorted(r['ms'] for r in records if r.get('kind') == 'sample' and r['mode'] == label and not r['warmup'])
    mid = len(values) // 2
    summary['metrics'][label] = {"median_ms": (values[mid-1]+values[mid])/2 if len(values)%2==0 else values[mid], "p95_ms": values[int(len(values)*.95 + .999999)-1], "min_ms": values[0], "max_ms": values[-1]}
(output / "records.json").write_text(json.dumps(records, indent=2), encoding="utf-8")
(output / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps(summary))
