insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('recipe-photos', 'recipe-photos', false, 5242880, array['image/jpeg','image/png','image/webp']);

create function private.photo_access(p_name text, p_write boolean) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare v_recipe uuid; v_owner uuid;
begin
  if auth.uid() is null or p_name is null or p_name !~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$' then return false; end if;
  v_owner := split_part(p_name, '/', 1)::uuid;
  v_recipe := split_part(p_name, '/', 2)::uuid;
  if not exists(select 1 from public.recipes where id = v_recipe and author_id = v_owner) then return false; end if;
  return case when p_write then private.owns_recipe(v_recipe) else private.can_read_recipe(v_recipe) end;
end;
$$;
revoke all on function private.photo_access(text, boolean) from public, anon;
grant execute on function private.photo_access(text, boolean) to authenticated;
create policy recipe_photo_read on storage.objects for select to authenticated
  using (bucket_id = 'recipe-photos' and private.photo_access(name, false));
create policy recipe_photo_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'recipe-photos' and private.photo_access(name, true));
create policy recipe_photo_update on storage.objects for update to authenticated
  using (bucket_id = 'recipe-photos' and private.photo_access(name, true))
  with check (bucket_id = 'recipe-photos' and private.photo_access(name, true));
create policy recipe_photo_delete on storage.objects for delete to authenticated
  using (bucket_id = 'recipe-photos' and private.photo_access(name, true));

-- DELETE events cannot re-evaluate RLS for a row that no longer exists.
-- Only INSERT/UPDATE; list.version updates signal item removals to authorized
-- readers, who must reload the authoritative list in Phase 07.
alter publication supabase_realtime set (publish = 'insert, update');
alter publication supabase_realtime add table public.shopping_lists, public.shopping_items;
alter table public.shopping_lists replica identity default;
alter table public.shopping_items replica identity default;
