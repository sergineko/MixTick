begin;
select plan(22);
select ok(not (select prosecdef from pg_proc where oid='public.cook_today_page(uuid[],text[],text,jsonb,integer)'::regprocedure),'Matching uses caller RLS');
select ok((select proconfig @> array['search_path=""'] from pg_proc where oid='public.cook_today_page(uuid[],text[],text,jsonb,integer)'::regprocedure),'Matching closes search path');
select ok(not has_function_privilege('anon','public.cook_today_page(uuid[],text[],text,jsonb,integer)','EXECUTE'),'No anonymous matching');
select ok(has_function_privilege('authenticated','public.cook_today_page(uuid[],text[],text,jsonb,integer)','EXECUTE'),'Authenticated matching');
select ok(exists(select 1 from pg_indexes where indexname='recipe_ingredients_free_match'),'Free exact matching index');
select is((select count(*)::integer from public.ingredients),50,'Catalog preserved');
select is((select count(*)::integer from public.ingredient_aliases),74,'Explicit aliases preserved');
select is((select count(*)::integer from pg_tables where schemaname='public'),16,'No pantry or new product tables');
-- SQL fixtures exist only in this rollback transaction. These checks are SQL
-- role tests, distinct from GoTrue-created A/B/C client evidence.
insert into auth.users(id,email) values
 ('30000000-0000-4000-8000-000000000001','matching-sql-a@example.test'),
 ('30000000-0000-4000-8000-000000000002','matching-sql-b@example.test'),
 ('30000000-0000-4000-8000-000000000003','matching-sql-c@example.test');
insert into public.profiles(user_id,username,display_name) values
 ('30000000-0000-4000-8000-000000000001','matching_sql_a','SQL A'),
 ('30000000-0000-4000-8000-000000000002','matching_sql_b','SQL B'),
 ('30000000-0000-4000-8000-000000000003','matching_sql_c','SQL C');
insert into public.recipes(id,author_id,title,category,servings,visibility,published_at)
select ('40000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('30000000-0000-4000-8000-'||lpad(actor::text,12,'0'))::uuid,
 title,'SQL matching',1,visibility,case when visibility='public' then now() end
from (values (1,1,'Private A','private'),(2,1,'One missing','public'),
 (3,1,'Legacy free alias','public'),(4,1,'Only optional','public'),
 (5,2,'Private B','private'),(6,3,'Private C','private')) v(n,actor,title,visibility);
insert into public.recipe_ingredients(recipe_id,ingredient_id,sort_order,quantity,unit,optional)
select ('40000000-0000-4000-8000-'||lpad(recipe::text,12,'0'))::uuid,
 ('10000000-0000-4000-8000-'||lpad(ingredient::text,12,'0'))::uuid,
 ordinal,qty,'kg',optional
from (values (1,4,0,1,false),(2,4,0,1,false),(2,3,1,1,false),
 (2,33,2,2,false),(2,2,3,1,true),(4,4,0,1,true),(5,4,0,1,false),(6,4,0,1,false))
 v(recipe,ingredient,ordinal,qty,optional);
insert into public.recipe_ingredients(recipe_id,custom_name,sort_order) values
 ('40000000-0000-4000-8000-000000000003','Huevos',0),
 ('40000000-0000-4000-8000-000000000003','Miso blanco',1);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*)::integer from public.cook_today_page(p_names=>array['Huevos']) j where j->'recipe'->>'title'='Private B'),1,'Own private recipe included');
select is((select count(*)::integer from public.cook_today_page(p_names=>array['Huevos']) j where j->'recipe'->>'title' in ('Private A','Private C')),0,'Foreign private recipes excluded');
select is((select count(*)::integer from public.cook_today_page(p_names=>array['Huevos','Patatas']) j where j->'recipe'->>'title'='One missing'),0,'Exact excludes missing required');
select is((select (j->>'missing')::integer from public.cook_today_page(p_names=>array['Huevos','Patatas'],p_mode=>'near') j where j->'recipe'->>'title'='One missing'),1,'Optional absence not counted; one required missing');
select is((select j->'missing_ingredients'->0->>'quantity' from public.cook_today_page(p_names=>array['Huevos','Patatas'],p_mode=>'near') j where j->'recipe'->>'title'='One missing'),'2.000','Original missing quantity retained');
select is((select (j->>'matched')::integer from public.cook_today_page(p_names=>array['HUEVOS','patatas','quesos']) j where j->'recipe'->>'title'='One missing'),3,'Full aliases resolve canonical IDs');
select is((select count(*)::integer from public.cook_today_page(p_ids=>array['10000000-0000-4000-8000-000000000004'::uuid],p_names=>array['Miso blanco']) j where j->'recipe'->>'title'='Legacy free alias'),1,'Legacy free name resolved by exact approved alias');
select is((select count(*)::integer from public.cook_today_page(p_names=>array['Huevos','MÍSO  blanco']) j where j->'recipe'->>'title'='Legacy free alias'),1,'Unknown free name exact normalization');
select is((select count(*)::integer from public.cook_today_page(p_names=>array['Huevos','miso']) j where j->'recipe'->>'title'='Legacy free alias'),0,'No substring free equivalence');
select is((select count(*)::integer from public.cook_today_page(p_names=>array['Huevos']) j where j->'recipe'->>'title'='Only optional'),0,'Optional-only recipes excluded');
select is((select count(*)::integer from public.cook_today_page()),0,'Empty selection has no universal results');
select is((select count(*)::integer from public.cook_today_page(p_names=>array['Tomates'],p_mode=>'near')),0,'Near needs at least one required overlap');
insert into public.user_blocks(blocked_id) values('30000000-0000-4000-8000-000000000001');
select is((select count(*)::integer from public.cook_today_page(p_names=>array['Huevos','Patatas','Quesos','Miso blanco']) j where j->'recipe'->>'author_id'='30000000-0000-4000-8000-000000000001'),0,'Blocked author excluded through RLS');
select is((select count(*)::integer from public.recipe_ingredients where recipe_id='40000000-0000-4000-8000-000000000001'),0,'Private child rows not exposed');
select * from finish();
rollback;
