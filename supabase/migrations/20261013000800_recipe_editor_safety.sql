-- Phase 04: preserve all historical RPCs. Add retry-safe creation, versioned
-- deletion and photo lifecycle support missing from the interactive editor.
create table private.recipe_creation_requests (
  actor_id uuid not null references public.profiles(user_id) on delete cascade,
  request_id uuid not null,
  payload_hash text not null,
  recipe_id uuid references public.recipes(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key(actor_id, request_id)
);
alter table private.recipe_creation_requests enable row level security;
revoke all on private.recipe_creation_requests from public, anon, authenticated;

create function private.create_recipe_once(p_request_id uuid, p_recipe jsonb,
  p_ingredients jsonb, p_steps jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_prior private.recipe_creation_requests; v_id uuid; v_hash text;
begin
  if auth.uid() is null then raise exception 'Sesión requerida' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'Solicitud requerida' using errcode='22023'; end if;
  v_hash := encode(extensions.digest(jsonb_build_array(p_recipe,p_ingredients,p_steps)::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || ':recipe:' || p_request_id::text,0));
  select * into v_prior from private.recipe_creation_requests
    where actor_id=auth.uid() and request_id=p_request_id;
  if found then
    if v_prior.recipe_id is null then raise exception 'La receta fue eliminada' using errcode='PT409'; end if;
    if v_prior.payload_hash <> v_hash then raise exception 'La solicitud ya tiene otro contenido' using errcode='PT409'; end if;
    return v_prior.recipe_id;
  end if;
  v_id := private.save_recipe(null,null,p_recipe,p_ingredients,p_steps);
  insert into private.recipe_creation_requests(actor_id,request_id,payload_hash,recipe_id)
    values(auth.uid(),p_request_id,v_hash,v_id);
  return v_id;
end;
$$;
create function public.create_recipe_once(p_request_id uuid, p_recipe jsonb,
  p_ingredients jsonb, p_steps jsonb) returns uuid
language sql security invoker set search_path = '' as $$
  select private.create_recipe_once(p_request_id,p_recipe,p_ingredients,p_steps);
$$;
create function private.lookup_recipe_creation(p_request_id uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select recipe_id from private.recipe_creation_requests
    where actor_id=auth.uid() and request_id=p_request_id;
$$;
create function public.lookup_recipe_creation(p_request_id uuid) returns uuid
language sql stable security invoker set search_path = '' as $$
  select private.lookup_recipe_creation(p_request_id);
$$;
create function private.delete_recipe_versioned(p_recipe_id uuid,p_expected_version bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare v_recipe public.recipes;
begin
  select * into v_recipe from public.recipes where id=p_recipe_id for update;
  if auth.uid() is null or v_recipe.id is null or v_recipe.author_id <> auth.uid() then
    raise exception 'Receta no accesible' using errcode='42501';
  end if;
  if p_expected_version is null or p_expected_version <> v_recipe.version then
    raise exception 'La receta ha cambiado; recarga antes de eliminar' using errcode='PT409';
  end if;
  delete from public.recipes where id=p_recipe_id;
end;
$$;
create function public.delete_recipe_versioned(p_recipe_id uuid,p_expected_version bigint) returns void
language sql security invoker set search_path = '' as $$
  select private.delete_recipe_versioned(p_recipe_id,p_expected_version);
$$;
-- Keep the historical owner write contract. Third parties can read only the
-- currently referenced image, never staged or replaced photos in that folder.
create or replace function private.photo_access(p_name text,p_write boolean) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare v_recipe public.recipes;
begin
  if auth.uid() is null or p_name is null or p_name !~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$' then return false; end if;
  select * into v_recipe from public.recipes where id=split_part(p_name,'/',2)::uuid
    and author_id=split_part(p_name,'/',1)::uuid;
  if v_recipe.id is null then return false; end if;
  if v_recipe.author_id=auth.uid() then return true; end if;
  return not p_write and v_recipe.hero_image_path=p_name and private.can_read_recipe(v_recipe.id);
end;
$$;
create function private.track_recipe_photo() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.bucket_id='recipe-photos' then
    insert into private.storage_cleanup_jobs(bucket_id,object_name) values(new.bucket_id,new.name)
      on conflict do nothing;
  end if;
  return new;
end;
$$;
create trigger staged_recipe_photo after insert on storage.objects
  for each row execute function private.track_recipe_photo();
create function private.replaced_recipe_photo() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.hero_image_path is distinct from new.hero_image_path then
    if old.hero_image_path is not null then
      insert into private.storage_cleanup_jobs(bucket_id,object_name)
        values('recipe-photos',old.hero_image_path) on conflict do nothing;
    end if;
    delete from private.storage_cleanup_jobs
      where bucket_id='recipe-photos' and object_name=new.hero_image_path;
  end if;
  return new;
end;
$$;
create trigger replaced_recipe_photo after update of hero_image_path on public.recipes
  for each row execute function private.replaced_recipe_photo();
-- Queue staging with a grace period in the future worker; always recheck the
-- active reference before physical removal. This migration does not delete blobs.
create index recipes_owner_recent on public.recipes(author_id,updated_at desc,id desc);
revoke all on function private.track_recipe_photo(), private.replaced_recipe_photo()
  from public,anon,authenticated;
revoke all on function private.create_recipe_once(uuid,jsonb,jsonb,jsonb),
  private.lookup_recipe_creation(uuid),private.delete_recipe_versioned(uuid,bigint),
  public.create_recipe_once(uuid,jsonb,jsonb,jsonb),public.lookup_recipe_creation(uuid),
  public.delete_recipe_versioned(uuid,bigint) from public,anon,authenticated;
grant execute on function private.create_recipe_once(uuid,jsonb,jsonb,jsonb),
  private.lookup_recipe_creation(uuid),private.delete_recipe_versioned(uuid,bigint),
  public.create_recipe_once(uuid,jsonb,jsonb,jsonb),public.lookup_recipe_creation(uuid),
  public.delete_recipe_versioned(uuid,bigint) to authenticated;
