-- Server-only queue consumer support. A durable fence closes the gap between
-- a database reference check and Storage's nontransactional physical DELETE.
alter table private.storage_cleanup_jobs
  add column owner_id text,
  add column not_before timestamptz not null default (clock_timestamp()+interval '24 hours'),
  add column state text not null default 'queued' check(state in ('queued','working','done','dead')),
  add column fenced boolean not null default false,
  add column attempts integer not null default 0 check(attempts between 0 and 5),
  add column claim_id uuid,
  add column lease_until timestamptz,
  add column error_code text check(error_code in ('invalid_path','owner_mismatch','referenced','storage_failure')),
  add column finished_at timestamptz;
update private.storage_cleanup_jobs set owner_id=split_part(object_name,'/',1),
  not_before=created_at+interval '24 hours';
create index storage_cleanup_due on private.storage_cleanup_jobs(not_before,id) where state in ('queued','working');

create function private.cleanup_valid_path(bucket text,path text) returns boolean
language sql immutable set search_path='' as $$
  select (bucket='recipe-photos' and path ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\.(jpg|png|webp)$')
    or (bucket='profile-avatars' and path ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\.(jpg|png|webp)$');
$$;
create function private.cleanup_referenced(bucket text,path text) returns boolean
language sql stable security definer set search_path='' as $$
  select (bucket='recipe-photos' and exists(select 1 from public.recipes where hero_image_path=path))
    or (bucket='profile-avatars' and exists(select 1 from public.profiles where avatar_path=path));
$$;
create function private.cleanup_owner() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.owner_id is null then new.owner_id:=split_part(new.object_name,'/',1); end if;
  return new;
end;
$$;
create trigger cleanup_owner before insert on private.storage_cleanup_jobs
  for each row execute function private.cleanup_owner();

create function private.lock_photo_reference(bucket text,path text,owner_uid uuid) returns void
language plpgsql security definer set search_path='' as $$
declare job private.storage_cleanup_jobs;
begin
  if path is null then return; end if;
  -- Reference writers lock the same row as claimers. Claimers never take the
  -- parent row lock, avoiding inverted recipe/profile -> job lock order.
  select * into job from private.storage_cleanup_jobs where bucket_id=bucket and object_name=path for update;
  if job.fenced then raise exception 'Fotografía en retirada; sube un archivo nuevo' using errcode='PT409'; end if;
  if not private.cleanup_valid_path(bucket,path) or split_part(path,'/',1)<>owner_uid::text or not exists(
    select 1 from storage.objects where bucket_id=bucket and name=path and owner_id=owner_uid::text) then
    raise exception 'Fotografía no disponible' using errcode='23514'; end if;
end;
$$;
create function private.photo_reference_fence() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_table_name='recipes' then
    if tg_op='INSERT' or new.hero_image_path is distinct from old.hero_image_path then
      perform private.lock_photo_reference('recipe-photos',new.hero_image_path,new.author_id);
    end if;
  else
    if tg_op='INSERT' or new.avatar_path is distinct from old.avatar_path then
      perform private.lock_photo_reference('profile-avatars',new.avatar_path,new.user_id);
      if new.avatar_path is not null then
        delete from private.storage_cleanup_jobs where bucket_id='profile-avatars' and object_name=new.avatar_path;
      end if;
    end if;
  end if;
  return new;
end;
$$;
create trigger photo_reference_fence before insert or update of hero_image_path on public.recipes
  for each row execute function private.photo_reference_fence();
create trigger photo_reference_fence before insert or update of avatar_path on public.profiles
  for each row execute function private.photo_reference_fence();
create function private.storage_path_fence() returns trigger
language plpgsql security definer set search_path='' as $$
declare job private.storage_cleanup_jobs;
begin
  if new.bucket_id in ('recipe-photos','profile-avatars') then
    select * into job from private.storage_cleanup_jobs where bucket_id=new.bucket_id and object_name=new.name for update;
    if job.fenced then raise exception 'Ruta retirada; usa una ruta nueva' using errcode='PT409'; end if;
  end if;
  return new;
end;
$$;
create trigger storage_path_fence before insert or update of name,bucket_id on storage.objects
  for each row execute function private.storage_path_fence();
create or replace function private.track_recipe_photo() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.bucket_id in ('recipe-photos','profile-avatars') then
    insert into private.storage_cleanup_jobs(bucket_id,object_name,owner_id)
      values(new.bucket_id,new.name,new.owner_id) on conflict do nothing;
  end if;
  return new;
end;
$$;

create function private.claim_storage_cleanup(p_limit integer default 10) returns setof jsonb
language plpgsql security definer set search_path='' as $$
declare job private.storage_cleanup_jobs; actual_owner text; token uuid;
begin
  if p_limit is null or p_limit not between 1 and 25 then raise exception 'Límite no válido' using errcode='22023'; end if;
  for job in select * from private.storage_cleanup_jobs where not_before<=clock_timestamp()
    and (state='queued' or (state='working' and lease_until<clock_timestamp()))
    order by not_before,id for update skip locked limit p_limit loop
    if not coalesce(private.cleanup_valid_path(job.bucket_id,job.object_name),false) then
      update private.storage_cleanup_jobs set state='dead',error_code='invalid_path',finished_at=clock_timestamp() where id=job.id;
      continue;
    end if;
    select o.owner_id into actual_owner from storage.objects o where o.bucket_id=job.bucket_id and o.name=job.object_name;
    if job.owner_id is distinct from split_part(job.object_name,'/',1) or (found and actual_owner is distinct from job.owner_id) then
      update private.storage_cleanup_jobs set state='dead',error_code='owner_mismatch',finished_at=clock_timestamp() where id=job.id;
      continue;
    end if;
    if private.cleanup_referenced(job.bucket_id,job.object_name) then
      if job.fenced then
        update private.storage_cleanup_jobs set state='dead',error_code='referenced',finished_at=clock_timestamp() where id=job.id;
      else delete from private.storage_cleanup_jobs where id=job.id;
      end if;
      continue;
    end if;
    if job.attempts>=5 then
      update private.storage_cleanup_jobs set state='dead',error_code='storage_failure',finished_at=clock_timestamp() where id=job.id;
      continue;
    end if;
    token:=gen_random_uuid();
    update private.storage_cleanup_jobs set state='working',fenced=true,attempts=attempts+1,
      claim_id=token,lease_until=clock_timestamp()+interval '2 minutes',error_code=null where id=job.id;
    return next jsonb_build_object('id',job.id,'claim_id',token,'bucket',job.bucket_id,'path',job.object_name);
  end loop;
end;
$$;
create function public.claim_storage_cleanup(p_limit integer default 10) returns setof jsonb
language sql security invoker set search_path='' as $$ select private.claim_storage_cleanup(p_limit); $$;
create function private.validate_storage_cleanup(p_id uuid,p_claim_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare job private.storage_cleanup_jobs; actual_owner text;
begin
  select * into job from private.storage_cleanup_jobs where id=p_id and claim_id=p_claim_id
    and state='working' and lease_until>clock_timestamp() for update;
  if not found or not private.cleanup_valid_path(job.bucket_id,job.object_name) then return false; end if;
  if private.cleanup_referenced(job.bucket_id,job.object_name) then return false; end if;
  select o.owner_id into actual_owner from storage.objects o where o.bucket_id=job.bucket_id and o.name=job.object_name;
  return job.owner_id=split_part(job.object_name,'/',1) and (not found or actual_owner=job.owner_id);
end;
$$;
create function public.validate_storage_cleanup(p_id uuid,p_claim_id uuid) returns boolean
language sql security invoker set search_path='' as $$ select private.validate_storage_cleanup(p_id,p_claim_id); $$;
create function private.finish_storage_cleanup(p_id uuid,p_claim_id uuid,p_removed boolean) returns void
language plpgsql security definer set search_path='' as $$
declare job private.storage_cleanup_jobs;
begin
  select * into job from private.storage_cleanup_jobs where id=p_id and claim_id=p_claim_id and state='working' for update;
  if not found then return; end if; -- stale claim cannot finalize a new lease
  if coalesce(p_removed,false) and not exists(select 1 from storage.objects where bucket_id=job.bucket_id and name=job.object_name) then
    update private.storage_cleanup_jobs set state='done',finished_at=clock_timestamp(),lease_until=null,error_code=null where id=job.id;
  else
    update private.storage_cleanup_jobs set state=case when attempts>=5 then 'dead' else 'queued' end,
      not_before=clock_timestamp()+make_interval(secs=>least(3600,30*(2^job.attempts)::integer)),
      finished_at=case when attempts>=5 then clock_timestamp() end,
      lease_until=null,error_code='storage_failure' where id=job.id;
  end if;
end;
$$;
create function public.finish_storage_cleanup(p_id uuid,p_claim_id uuid,p_removed boolean) returns void
language sql security invoker set search_path='' as $$ select private.finish_storage_cleanup(p_id,p_claim_id,p_removed); $$;

-- A client cannot physically delete its active image and leave a dangling ref.
alter policy recipe_photo_delete on storage.objects using (bucket_id='recipe-photos'
  and private.photo_access(name,true) and not exists(select 1 from public.recipes r where r.hero_image_path=name));
alter policy avatar_delete on storage.objects using (bucket_id='profile-avatars'
  and private.avatar_access(name,true) and not exists(select 1 from public.profiles p where p.avatar_path=name));

revoke all on function private.cleanup_valid_path(text,text),private.cleanup_referenced(text,text),private.cleanup_owner(),
  private.lock_photo_reference(text,text,uuid),private.photo_reference_fence(),private.storage_path_fence() from public,anon,authenticated;
grant usage on schema private to service_role;
do $$ declare f record; begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.proname in ('claim_storage_cleanup','validate_storage_cleanup','finish_storage_cleanup') loop
    execute format('revoke all on function %s from public,anon,authenticated',f.signature);
    execute format('grant execute on function %s to service_role',f.signature);
  end loop;
end $$;
