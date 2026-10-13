-- Phase 03 adds only the storage support missing for profiles.avatar_path.
-- Auth does not auto-create a username from private email/metadata: onboarding
-- inserts the existing profile using its auth.uid() default and RLS.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('profile-avatars', 'profile-avatars', false, 2097152,
  array['image/jpeg','image/png','image/webp']);

alter table public.profiles add constraint profile_avatar_owner check (
  avatar_path is null or (
    avatar_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'
    and split_part(avatar_path, '/', 1) = user_id::text));

create function private.avatar_access(p_name text, p_write boolean) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and p_name ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'
    and exists (select 1 from public.profiles p
      where p.user_id::text = split_part(p_name, '/', 1) and
        (p.user_id = auth.uid() or
          (not p_write and p.avatar_path = p_name and private.is_unblocked(p.user_id))));
$$;
revoke all on function private.avatar_access(text, boolean) from public, anon;
grant execute on function private.avatar_access(text, boolean) to authenticated;

create policy avatar_read on storage.objects for select to authenticated
  using (bucket_id = 'profile-avatars' and private.avatar_access(name, false));
create policy avatar_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'profile-avatars' and private.avatar_access(name, true));
create policy avatar_update on storage.objects for update to authenticated
  using (bucket_id = 'profile-avatars' and private.avatar_access(name, true))
  with check (bucket_id = 'profile-avatars' and private.avatar_access(name, true));
create policy avatar_delete on storage.objects for delete to authenticated
  using (bucket_id = 'profile-avatars' and private.avatar_access(name, true));

create function private.validate_profile_avatar() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.avatar_path is not null and (tg_op = 'INSERT' or new.avatar_path is distinct from old.avatar_path)
    and not exists (select 1 from storage.objects o
      where o.bucket_id = 'profile-avatars' and o.name = new.avatar_path
        and o.owner_id = new.user_id::text) then
    raise exception 'La foto debe existir y pertenecer al usuario' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger profile_avatar_exists before insert or update of avatar_path on public.profiles
for each row execute function private.validate_profile_avatar();
revoke all on function private.validate_profile_avatar() from public, anon, authenticated;

-- Previous files become unreadable to others as soon as avatar_path changes.
-- Normal client deletion removes their bytes; queue is a launch-gate fallback.
create function private.queue_profile_avatars() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    insert into private.storage_cleanup_jobs(bucket_id, object_name)
      select bucket_id, name from storage.objects
      where bucket_id = 'profile-avatars' and split_part(name, '/', 1) = old.user_id::text
      on conflict do nothing;
    return old;
  elsif old.avatar_path is not null and new.avatar_path is distinct from old.avatar_path then
    insert into private.storage_cleanup_jobs(bucket_id, object_name)
      values ('profile-avatars', old.avatar_path) on conflict do nothing;
  end if;
  return new;
end;
$$;
create trigger replaced_profile_avatar after update of avatar_path on public.profiles
for each row execute function private.queue_profile_avatars();
create trigger deleted_profile_avatars before delete on public.profiles
for each row execute function private.queue_profile_avatars();
revoke all on function private.queue_profile_avatars() from public, anon, authenticated;
