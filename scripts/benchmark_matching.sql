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
\timing on
select jsonb_build_object('mode','exact','returned',count(*),'complete',bool_and((j->>'missing')::integer=0),
 'no_steps',bool_and(not (j->'recipe' ? 'recipe_steps'))) from public.cook_today_page(p_names=>array['Huevos','Patatas'],p_limit=>9) j;
select jsonb_build_object('mode','near','returned',count(*),'required_overlap',bool_and((j->>'matched')::integer>0))
 from public.cook_today_page(p_names=>array['Huevos','Patatas'],p_mode=>'near',p_limit=>9) j;
select jsonb_build_object('mode','next','returned',count(*),'no_overlap',bool_and((j->'recipe'->>'id')::uuid>'70000000-0000-4000-8000-000000000014'::uuid))
 from public.cook_today_page(p_names=>array['Huevos','Patatas'],p_after=>'{"missing":0,"rank":0,"minutes":15,"id":"70000000-0000-4000-8000-000000000014"}',p_limit=>9) j;
do $$ declare v_count integer; begin
  select count(*) into v_count from public.cook_today_page(p_names=>array['Huevos','Patatas'],p_limit=>9);
  if v_count<>9 then raise exception 'Benchmark page assertion failed'; end if;
end $$;
\timing off
rollback;
select jsonb_build_object('remaining_fixture_users',(select count(*) from auth.users),
 'remaining_recipes',(select count(*) from public.recipes));
