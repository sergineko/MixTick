-- Read-only local schema audit. No user data, credentials or object paths.
select jsonb_build_object('kind','schema','migrations',
 (select count(*) from supabase_migrations.schema_migrations),
 'tables',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,'rls',c.relrowsecurity) order by n.nspname,c.relname)
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname in ('public','private') and c.relkind='r'));
select jsonb_build_object('kind','definers','unsafe_search_path',
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in ('public','private') and p.prosecdef and not exists(
 select 1 from unnest(p.proconfig) v where v in ('search_path=""','search_path='))),
 'public_definers',(select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosecdef));
select jsonb_build_object('kind','service_rpc','ordinary_execute',
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('claim_storage_cleanup','validate_storage_cleanup','finish_storage_cleanup',
 'begin_account_deletion','claim_account_deletions','finish_account_deletion','maintain_private_operations')
 and (has_function_privilege('anon',p.oid,'execute') or has_function_privilege('authenticated',p.oid,'execute'))));
select jsonb_build_object('kind','buckets','public_buckets',(select count(*) from storage.buckets where public),
 'bucket_count',(select count(*) from storage.buckets),
 'realtime_tables',(select jsonb_agg(tablename order by tablename) from pg_publication_tables where pubname='supabase_realtime'));
select jsonb_build_object('kind','fixtures','auth_users',(select count(*) from auth.users),
 'profiles',(select count(*) from public.profiles),'recipes',(select count(*) from public.recipes),
 'shopping_lists',(select count(*) from public.shopping_lists),'storage_objects',(select count(*) from storage.objects),
 'cleanup_jobs',(select count(*) from private.storage_cleanup_jobs),'account_jobs',(select count(*) from private.account_deletions),
 'operators',(select count(*) from private.moderation_operators),'actions',(select count(*) from private.moderation_actions),
 'ingredients',(select count(*) from public.ingredients),'aliases',(select count(*) from public.ingredient_aliases));
