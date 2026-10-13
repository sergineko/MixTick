begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;
select plan(19);
select is((select count(*)::integer from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'), 16, 'Exactly 16 product/support tables');
select ok((select bool_and(c.relrowsecurity) from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public','private') and c.relkind = 'r'), 'RLS enabled on all product and technical tables');
select is((select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef), 0, 'No exposed SECURITY DEFINER functions');
select ok((select bool_and(p.proconfig @> array['search_path=""']) from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.prosecdef), 'Every definer pins empty search_path');
select ok((select bool_and(not has_function_privilege('anon', p.oid, 'EXECUTE')) from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace where n.nspname in ('public','private')), 'Anon cannot execute app functions');
select ok(not has_function_privilege('authenticated', 'private.require_list(uuid,boolean)', 'EXECUTE'), 'Internal lock helper not callable');
select ok(not has_table_privilege('authenticated', 'private.shopping_imports', 'SELECT'), 'Import ledger hidden');
select ok(not has_table_privilege('authenticated', 'private.storage_cleanup_jobs', 'SELECT'), 'Cleanup queue hidden');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'user_id', 'INSERT'), 'Profile identity immutable');
select ok(not has_table_privilege('authenticated', 'public.recipes', 'UPDATE'), 'Recipe aggregate requires RPC');
select ok(not has_table_privilege('authenticated', 'public.shopping_list_members', 'INSERT'), 'Membership requires acceptance RPC');
select ok(not has_table_privilege('authenticated', 'public.shopping_items', 'UPDATE'), 'Item writes require version checks');
select ok((select not public and file_size_limit = 5242880 from storage.buckets where id = 'recipe-photos'), 'Photos in private size-limited bucket');
select ok((select not pubdelete from pg_publication where pubname = 'supabase_realtime'), 'No unauthorized DELETE metadata broadcast');
select is((select count(*)::integer from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public'), 2, 'Only lists and items in Realtime');
select is((select count(*)::integer from public.ingredients where approved), 50, '50 approved Spanish ingredients');
select is((select count(*)::integer from public.ingredient_aliases), 74, '74 canonical names and curated aliases');
select is(private.normalize_text('  CALABACÍN  '), 'calabacin', 'Normalization handles case accents and space');
select is((select pg_get_expr(adbin, adrelid) from pg_attrdef d join pg_attribute a
  on a.attrelid = d.adrelid and a.attnum = d.adnum where d.adrelid = 'public.recipes'::regclass and a.attname = 'visibility'),
  '''private''::text', 'Database default is private');
select * from finish();
rollback;
