-- Local-only SQL benchmark. All fixtures roll back; no production claim.
begin;
do $$ begin
  if exists(select 1 from auth.users) then raise exception 'Benchmark requires an empty fixture project'; end if;
end $$;
insert into auth.users(id,email) select
 ('60000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'matching-benchmark-'||n||'@example.test' from generate_series(1,3) n;
insert into public.profiles(user_id,username,display_name) select
 ('60000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'matching_benchmark_'||n,'Benchmark '||n from generate_series(1,3) n;
insert into public.recipes(id,author_id,title,category,servings,prep_minutes,cook_minutes,visibility,published_at)
select ('70000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('60000000-0000-4000-8000-'||lpad((n%3+1)::text,12,'0'))::uuid,
 'Benchmark '||n,'Benchmark',1,5,10,case when n%5=0 then 'private' else 'public' end,
 case when n%5<>0 then now() end from generate_series(1,6000) n;
insert into public.recipe_ingredients(recipe_id,ingredient_id,sort_order,optional)
select ('70000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('10000000-0000-4000-8000-'||lpad(ingredient::text,12,'0'))::uuid,ordinal,
 ordinal=2 and n%3<>0 from generate_series(1,6000) n
 cross join (values (4,0),(3,1),(33,2)) v(ingredient,ordinal);
insert into public.recipe_steps(recipe_id,sort_order,instruction)
 select id,0,'Paso de benchmark' from public.recipes;
analyze public.recipes;
analyze public.recipe_ingredients;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"60000000-0000-4000-8000-000000000002","role":"authenticated"}',true);

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
select jsonb_build_object('kind','plan','mode','exact','type','inner','plan',pg_temp.plan($query$with candidates as materialized (
    -- At least one matching REQUIRED key. Existing FK and new free-key indexes
    -- support the candidate set; unrelated/optional-only recipes are not scored.
    select distinct ri.recipe_id from public.recipe_ingredients ri
    left join public.ingredient_aliases a on a.normalized_alias=ri.custom_key
    left join public.ingredients known on known.id=a.ingredient_id and known.approved
    where not ri.optional and (
      coalesce(ri.ingredient_id,known.id)=any(array['10000000-0000-4000-8000-000000000004'::uuid,'10000000-0000-4000-8000-000000000003'::uuid]) or
      (coalesce(ri.ingredient_id,known.id) is null and ri.custom_key=any('{}'::text[])))
  ), lines as materialized (
    select ri.*, coalesce(ri.ingredient_id,known.id) effective_id,
      coalesce(i.canonical_name_es,ri.custom_name) item_name,
      coalesce(ri.ingredient_id::text,known.id::text,'free:'||ri.custom_key) match_key,
      coalesce(coalesce(ri.ingredient_id,known.id)=any(array['10000000-0000-4000-8000-000000000004'::uuid,'10000000-0000-4000-8000-000000000003'::uuid]),false) or
        (coalesce(ri.ingredient_id,known.id) is null and ri.custom_key=any('{}'::text[])) present
    from candidates c join public.recipe_ingredients ri on ri.recipe_id=c.recipe_id
    left join public.ingredients i on i.id=ri.ingredient_id
    left join public.ingredient_aliases a on a.normalized_alias=ri.custom_key
    left join public.ingredients known on known.id=a.ingredient_id and known.approved
  ), keys as (
    select recipe_id,match_key,bool_and(optional) optional,bool_or(present) present
    from lines group by recipe_id,match_key
  ), counts as (
    select recipe_id,count(*) filter(where not optional)::integer required,
      count(*) filter(where not optional and present)::integer matched,
      count(*) filter(where not optional and not present)::integer missing,
      count(*) filter(where optional and present)::integer optional_matched
    from keys group by recipe_id
  ), scored as (
    select r.*,p.username,p.display_name,p.avatar_path,c.required,c.matched,c.missing,c.optional_matched,
      case when c.missing=0 then -c.optional_matched else -c.matched end rank,
      case when r.prep_minutes is null and r.cook_minutes is null then 20161
        else coalesce(r.prep_minutes,0)+coalesce(r.cook_minutes,0) end minutes
    from counts c join public.recipes r on r.id=c.recipe_id
      join public.profiles p on p.user_id=r.author_id
    where c.required>0 and c.matched>0 and
      (('exact'='exact' and c.missing=0) or ('exact'='near' and c.missing<=2))
  ), page as materialized (
    select * from scored r where null::jsonb is null or
      (r.missing,r.rank,r.minutes,r.id)>(0,0,15,'70000000-0000-4000-8000-000000000014'::uuid)
    order by r.missing,r.rank,r.minutes,r.id limit 9
  )
  select jsonb_build_object(
    'recipe',jsonb_build_object('id',r.id,'author_id',r.author_id,'title',r.title,
      'description',r.description,'category',r.category,'servings',r.servings,
      'prep_minutes',r.prep_minutes,'cook_minutes',r.cook_minutes,'visibility',r.visibility,
      'hero_image_path',r.hero_image_path,'version',r.version,'updated_at',r.updated_at),
    'author',jsonb_build_object('username',r.username,'display_name',r.display_name,'avatar_path',r.avatar_path),
    'required',r.required,'matched',r.matched,'missing',r.missing,'optional_matched',r.optional_matched,
    'cursor',jsonb_build_object('missing',r.missing,'rank',r.rank,'minutes',r.minutes,'id',r.id),
    'missing_ingredients',coalesce((select jsonb_agg(jsonb_build_object(
      'line_id',l.id,'sort_order',l.sort_order,'effective_id',l.effective_id,
      'ingredient_id',l.ingredient_id,'custom_name',l.custom_name,
      'ingredients',jsonb_build_object('canonical_name_es',l.item_name),
      'quantity',l.quantity,'unit',l.unit,'optional',l.optional) order by l.sort_order)
      from lines l where l.recipe_id=r.id and not l.optional and not l.present),'[]'::jsonb)
  ) from page r order by r.missing,r.rank,r.minutes,r.id$query$));
select jsonb_build_object('kind','plan','mode','exact','type','rpc','plan',pg_temp.plan($query$select * from public.cook_today_page(p_names=>array['Huevos','Patatas'],p_mode=>'exact',p_after=>null::jsonb,p_limit=>9)$query$));
select pg_temp.sample('exact',null::jsonb,true,0);
select pg_temp.sample('exact',null::jsonb,true,1);
select pg_temp.sample('exact',null::jsonb,false,2);
select pg_temp.sample('exact',null::jsonb,false,3);
select pg_temp.sample('exact',null::jsonb,false,4);
select pg_temp.sample('exact',null::jsonb,false,5);
select pg_temp.sample('exact',null::jsonb,false,6);
select pg_temp.sample('exact',null::jsonb,false,7);
select pg_temp.sample('exact',null::jsonb,false,8);
select pg_temp.sample('exact',null::jsonb,false,9);
select pg_temp.sample('exact',null::jsonb,false,10);
select pg_temp.sample('exact',null::jsonb,false,11);
select pg_temp.sample('exact',null::jsonb,false,12);
select pg_temp.sample('exact',null::jsonb,false,13);
select pg_temp.sample('exact',null::jsonb,false,14);
select pg_temp.sample('exact',null::jsonb,false,15);
select pg_temp.sample('exact',null::jsonb,false,16);
select pg_temp.sample('exact',null::jsonb,false,17);
select pg_temp.sample('exact',null::jsonb,false,18);
select pg_temp.sample('exact',null::jsonb,false,19);
select pg_temp.sample('exact',null::jsonb,false,20);
select pg_temp.sample('exact',null::jsonb,false,21);
select pg_temp.sample('exact',null::jsonb,false,22);
select pg_temp.sample('exact',null::jsonb,false,23);
select pg_temp.sample('exact',null::jsonb,false,24);
select pg_temp.sample('exact',null::jsonb,false,25);
select pg_temp.sample('exact',null::jsonb,false,26);
select pg_temp.sample('exact',null::jsonb,false,27);
select pg_temp.sample('exact',null::jsonb,false,28);
select pg_temp.sample('exact',null::jsonb,false,29);
select pg_temp.sample('exact',null::jsonb,false,30);
select pg_temp.sample('exact',null::jsonb,false,31);
select jsonb_build_object('kind','plan','mode','near','type','inner','plan',pg_temp.plan($query$with candidates as materialized (
    -- At least one matching REQUIRED key. Existing FK and new free-key indexes
    -- support the candidate set; unrelated/optional-only recipes are not scored.
    select distinct ri.recipe_id from public.recipe_ingredients ri
    left join public.ingredient_aliases a on a.normalized_alias=ri.custom_key
    left join public.ingredients known on known.id=a.ingredient_id and known.approved
    where not ri.optional and (
      coalesce(ri.ingredient_id,known.id)=any(array['10000000-0000-4000-8000-000000000004'::uuid,'10000000-0000-4000-8000-000000000003'::uuid]) or
      (coalesce(ri.ingredient_id,known.id) is null and ri.custom_key=any('{}'::text[])))
  ), lines as materialized (
    select ri.*, coalesce(ri.ingredient_id,known.id) effective_id,
      coalesce(i.canonical_name_es,ri.custom_name) item_name,
      coalesce(ri.ingredient_id::text,known.id::text,'free:'||ri.custom_key) match_key,
      coalesce(coalesce(ri.ingredient_id,known.id)=any(array['10000000-0000-4000-8000-000000000004'::uuid,'10000000-0000-4000-8000-000000000003'::uuid]),false) or
        (coalesce(ri.ingredient_id,known.id) is null and ri.custom_key=any('{}'::text[])) present
    from candidates c join public.recipe_ingredients ri on ri.recipe_id=c.recipe_id
    left join public.ingredients i on i.id=ri.ingredient_id
    left join public.ingredient_aliases a on a.normalized_alias=ri.custom_key
    left join public.ingredients known on known.id=a.ingredient_id and known.approved
  ), keys as (
    select recipe_id,match_key,bool_and(optional) optional,bool_or(present) present
    from lines group by recipe_id,match_key
  ), counts as (
    select recipe_id,count(*) filter(where not optional)::integer required,
      count(*) filter(where not optional and present)::integer matched,
      count(*) filter(where not optional and not present)::integer missing,
      count(*) filter(where optional and present)::integer optional_matched
    from keys group by recipe_id
  ), scored as (
    select r.*,p.username,p.display_name,p.avatar_path,c.required,c.matched,c.missing,c.optional_matched,
      case when c.missing=0 then -c.optional_matched else -c.matched end rank,
      case when r.prep_minutes is null and r.cook_minutes is null then 20161
        else coalesce(r.prep_minutes,0)+coalesce(r.cook_minutes,0) end minutes
    from counts c join public.recipes r on r.id=c.recipe_id
      join public.profiles p on p.user_id=r.author_id
    where c.required>0 and c.matched>0 and
      (('near'='exact' and c.missing=0) or ('near'='near' and c.missing<=2))
  ), page as materialized (
    select * from scored r where null::jsonb is null or
      (r.missing,r.rank,r.minutes,r.id)>(0,0,15,'70000000-0000-4000-8000-000000000014'::uuid)
    order by r.missing,r.rank,r.minutes,r.id limit 9
  )
  select jsonb_build_object(
    'recipe',jsonb_build_object('id',r.id,'author_id',r.author_id,'title',r.title,
      'description',r.description,'category',r.category,'servings',r.servings,
      'prep_minutes',r.prep_minutes,'cook_minutes',r.cook_minutes,'visibility',r.visibility,
      'hero_image_path',r.hero_image_path,'version',r.version,'updated_at',r.updated_at),
    'author',jsonb_build_object('username',r.username,'display_name',r.display_name,'avatar_path',r.avatar_path),
    'required',r.required,'matched',r.matched,'missing',r.missing,'optional_matched',r.optional_matched,
    'cursor',jsonb_build_object('missing',r.missing,'rank',r.rank,'minutes',r.minutes,'id',r.id),
    'missing_ingredients',coalesce((select jsonb_agg(jsonb_build_object(
      'line_id',l.id,'sort_order',l.sort_order,'effective_id',l.effective_id,
      'ingredient_id',l.ingredient_id,'custom_name',l.custom_name,
      'ingredients',jsonb_build_object('canonical_name_es',l.item_name),
      'quantity',l.quantity,'unit',l.unit,'optional',l.optional) order by l.sort_order)
      from lines l where l.recipe_id=r.id and not l.optional and not l.present),'[]'::jsonb)
  ) from page r order by r.missing,r.rank,r.minutes,r.id$query$));
select jsonb_build_object('kind','plan','mode','near','type','rpc','plan',pg_temp.plan($query$select * from public.cook_today_page(p_names=>array['Huevos','Patatas'],p_mode=>'near',p_after=>null::jsonb,p_limit=>9)$query$));
select pg_temp.sample('near',null::jsonb,true,0);
select pg_temp.sample('near',null::jsonb,true,1);
select pg_temp.sample('near',null::jsonb,false,2);
select pg_temp.sample('near',null::jsonb,false,3);
select pg_temp.sample('near',null::jsonb,false,4);
select pg_temp.sample('near',null::jsonb,false,5);
select pg_temp.sample('near',null::jsonb,false,6);
select pg_temp.sample('near',null::jsonb,false,7);
select pg_temp.sample('near',null::jsonb,false,8);
select pg_temp.sample('near',null::jsonb,false,9);
select pg_temp.sample('near',null::jsonb,false,10);
select pg_temp.sample('near',null::jsonb,false,11);
select pg_temp.sample('near',null::jsonb,false,12);
select pg_temp.sample('near',null::jsonb,false,13);
select pg_temp.sample('near',null::jsonb,false,14);
select pg_temp.sample('near',null::jsonb,false,15);
select pg_temp.sample('near',null::jsonb,false,16);
select pg_temp.sample('near',null::jsonb,false,17);
select pg_temp.sample('near',null::jsonb,false,18);
select pg_temp.sample('near',null::jsonb,false,19);
select pg_temp.sample('near',null::jsonb,false,20);
select pg_temp.sample('near',null::jsonb,false,21);
select pg_temp.sample('near',null::jsonb,false,22);
select pg_temp.sample('near',null::jsonb,false,23);
select pg_temp.sample('near',null::jsonb,false,24);
select pg_temp.sample('near',null::jsonb,false,25);
select pg_temp.sample('near',null::jsonb,false,26);
select pg_temp.sample('near',null::jsonb,false,27);
select pg_temp.sample('near',null::jsonb,false,28);
select pg_temp.sample('near',null::jsonb,false,29);
select pg_temp.sample('near',null::jsonb,false,30);
select pg_temp.sample('near',null::jsonb,false,31);
select jsonb_build_object('kind','plan','mode','next','type','inner','plan',pg_temp.plan($query$with candidates as materialized (
    -- At least one matching REQUIRED key. Existing FK and new free-key indexes
    -- support the candidate set; unrelated/optional-only recipes are not scored.
    select distinct ri.recipe_id from public.recipe_ingredients ri
    left join public.ingredient_aliases a on a.normalized_alias=ri.custom_key
    left join public.ingredients known on known.id=a.ingredient_id and known.approved
    where not ri.optional and (
      coalesce(ri.ingredient_id,known.id)=any(array['10000000-0000-4000-8000-000000000004'::uuid,'10000000-0000-4000-8000-000000000003'::uuid]) or
      (coalesce(ri.ingredient_id,known.id) is null and ri.custom_key=any('{}'::text[])))
  ), lines as materialized (
    select ri.*, coalesce(ri.ingredient_id,known.id) effective_id,
      coalesce(i.canonical_name_es,ri.custom_name) item_name,
      coalesce(ri.ingredient_id::text,known.id::text,'free:'||ri.custom_key) match_key,
      coalesce(coalesce(ri.ingredient_id,known.id)=any(array['10000000-0000-4000-8000-000000000004'::uuid,'10000000-0000-4000-8000-000000000003'::uuid]),false) or
        (coalesce(ri.ingredient_id,known.id) is null and ri.custom_key=any('{}'::text[])) present
    from candidates c join public.recipe_ingredients ri on ri.recipe_id=c.recipe_id
    left join public.ingredients i on i.id=ri.ingredient_id
    left join public.ingredient_aliases a on a.normalized_alias=ri.custom_key
    left join public.ingredients known on known.id=a.ingredient_id and known.approved
  ), keys as (
    select recipe_id,match_key,bool_and(optional) optional,bool_or(present) present
    from lines group by recipe_id,match_key
  ), counts as (
    select recipe_id,count(*) filter(where not optional)::integer required,
      count(*) filter(where not optional and present)::integer matched,
      count(*) filter(where not optional and not present)::integer missing,
      count(*) filter(where optional and present)::integer optional_matched
    from keys group by recipe_id
  ), scored as (
    select r.*,p.username,p.display_name,p.avatar_path,c.required,c.matched,c.missing,c.optional_matched,
      case when c.missing=0 then -c.optional_matched else -c.matched end rank,
      case when r.prep_minutes is null and r.cook_minutes is null then 20161
        else coalesce(r.prep_minutes,0)+coalesce(r.cook_minutes,0) end minutes
    from counts c join public.recipes r on r.id=c.recipe_id
      join public.profiles p on p.user_id=r.author_id
    where c.required>0 and c.matched>0 and
      (('exact'='exact' and c.missing=0) or ('exact'='near' and c.missing<=2))
  ), page as materialized (
    select * from scored r where '{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb is null or
      (r.missing,r.rank,r.minutes,r.id)>(0,0,15,'70000000-0000-4000-8000-000000000014'::uuid)
    order by r.missing,r.rank,r.minutes,r.id limit 9
  )
  select jsonb_build_object(
    'recipe',jsonb_build_object('id',r.id,'author_id',r.author_id,'title',r.title,
      'description',r.description,'category',r.category,'servings',r.servings,
      'prep_minutes',r.prep_minutes,'cook_minutes',r.cook_minutes,'visibility',r.visibility,
      'hero_image_path',r.hero_image_path,'version',r.version,'updated_at',r.updated_at),
    'author',jsonb_build_object('username',r.username,'display_name',r.display_name,'avatar_path',r.avatar_path),
    'required',r.required,'matched',r.matched,'missing',r.missing,'optional_matched',r.optional_matched,
    'cursor',jsonb_build_object('missing',r.missing,'rank',r.rank,'minutes',r.minutes,'id',r.id),
    'missing_ingredients',coalesce((select jsonb_agg(jsonb_build_object(
      'line_id',l.id,'sort_order',l.sort_order,'effective_id',l.effective_id,
      'ingredient_id',l.ingredient_id,'custom_name',l.custom_name,
      'ingredients',jsonb_build_object('canonical_name_es',l.item_name),
      'quantity',l.quantity,'unit',l.unit,'optional',l.optional) order by l.sort_order)
      from lines l where l.recipe_id=r.id and not l.optional and not l.present),'[]'::jsonb)
  ) from page r order by r.missing,r.rank,r.minutes,r.id$query$));
select jsonb_build_object('kind','plan','mode','next','type','rpc','plan',pg_temp.plan($query$select * from public.cook_today_page(p_names=>array['Huevos','Patatas'],p_mode=>'exact',p_after=>'{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,p_limit=>9)$query$));
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,true,0);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,true,1);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,2);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,3);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,4);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,5);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,6);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,7);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,8);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,9);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,10);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,11);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,12);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,13);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,14);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,15);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,16);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,17);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,18);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,19);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,20);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,21);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,22);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,23);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,24);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,25);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,26);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,27);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,28);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,29);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,30);
select pg_temp.sample('exact','{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}'::jsonb,false,31);
rollback;
select jsonb_build_object('kind','cleanup','auth',(select count(*) from auth.users),'recipes',(select count(*) from public.recipes));
