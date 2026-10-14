"""Compare preserved local evidence, without touching the database."""
import json
from pathlib import Path

root=Path(__file__).resolve().parents[1]/'docs/reports/phase08/evidence'
records={name:json.loads((root/f'benchmark-{name}/records.json').read_text()) for name in ('before','after-012','after-015')}
summary={name:json.loads((root/f'benchmark-{name}/summary.json').read_text()) for name in records}
environment=[next(r for r in rows if r.get('kind')=='environment') for rows in records.values()]
assert all(e['rls']=='on' and e['fixture_recipes']==6000 and e['fixture_lines']==18000 and e['fixture_steps']==6000 for e in environment)
out={}
for mode in ('exact','near','next'):
    hashes=[];plans={}
    for name,rows in records.items():
        samples=[r for r in rows if r.get('kind')=='sample' and r['mode']==mode]
        assert len(samples)==32 and sum(not r['warmup'] for r in samples)==30
        assert all(r['rows']==9 for r in samples)
        hashes.append({r['result_hash'] for r in samples})
        plan=next(r['plan'][0] for r in rows if r.get('kind')=='plan' and r['type']=='inner' and r['mode']==mode)
        nodes=[]
        def walk(node):
            nodes.append(node)
            for child in node.get('Plans',[]):walk(child)
        walk(plan['Plan'])
        memory=[n['Peak Memory Usage'] for n in nodes if 'Peak Memory Usage' in n]
        plans[name]={'execution_ms':plan['Execution Time'],'root_shared_hits':plan['Plan'].get('Shared Hit Blocks'),
          'root_shared_reads':plan['Plan'].get('Shared Read Blocks'),
          'max_reported_node_memory_kb':max(memory) if memory else None,
          'indexes':sorted({n['Index Name'] for n in nodes if 'Index Name' in n}),
          'largest_repeated_nodes':[{'node':n['Node Type'],'relation':n.get('Relation Name'),
              'loops':n['Actual Loops'],'rows_per_loop':n['Actual Rows'],'total_time_per_loop_ms':n['Actual Total Time']}
              for n in sorted(nodes,key=lambda n:n.get('Actual Loops',0),reverse=True)[:8]]}
    assert hashes[0]==hashes[1]==hashes[2] and len(hashes[0])==1
    before,after=summary['before']['metrics'][mode],summary['after-015']['metrics'][mode]
    out[mode]={'status':'PASS','identical_result_hashes':True,'samples_per_stage':32,
      'before':before,'after':after,'plans':plans,
      'median_reduction_pct':round(100*(1-after['median_ms']/before['median_ms']),3),
      'p95_reduction_pct':round(100*(1-after['p95_ms']/before['p95_ms']),3)}
(root/'benchmark-comparison.json').write_text(json.dumps(out,indent=2))
print('PASS: same RLS/6000/18000/6000 fixtures, 32 samples/stage/mode, nine rows, identical hashes; plans compared')
