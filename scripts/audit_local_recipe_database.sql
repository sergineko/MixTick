-- Read-only trusted host audit, not a substitute for Auth/RLS client tests.
select json_build_object(
 'postgres_version',current_setting('server_version'),
 'migrations',(select json_agg(version order by version) from supabase_migrations.schema_migrations),
 'public_tables',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r'),
 'private_tables',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='private' and c.relkind='r'),
 'approved_ingredients',(select count(*) from public.ingredients where approved),
 'aliases',(select count(*) from public.ingredient_aliases),
 'auth_users',(select count(*) from auth.users),
 'profiles',(select count(*) from public.profiles),
 'recipes',(select count(*) from public.recipes),
 'recipe_ingredients',(select count(*) from public.recipe_ingredients),
 'recipe_steps',(select count(*) from public.recipe_steps),
 'shopping_lists',(select count(*) from public.shopping_lists),
 'shopping_items',(select count(*) from public.shopping_items),
 'recipe_photos',(select count(*) from storage.objects where bucket_id='recipe-photos'),
 'avatars',(select count(*) from storage.objects where bucket_id='profile-avatars'),
 'cleanup_jobs',(select count(*) from private.storage_cleanup_jobs),
 'recipe_creation_requests',(select count(*) from private.recipe_creation_requests),
 'creation_windows',(select count(*) from private.creation_windows),
 'import_ledger',(select count(*) from private.shopping_imports)
);
