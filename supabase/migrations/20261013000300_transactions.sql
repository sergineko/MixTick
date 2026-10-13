-- Definer implementations live in non-exposed private; public entry points
-- are invoker wrappers. Every operation checks auth.uid() and locks authority.
create function private.require_list(p_list_id uuid, p_owner_only boolean default false)
returns public.shopping_lists language plpgsql security definer set search_path = '' as $$
declare v_list public.shopping_lists;
begin
  select * into v_list from public.shopping_lists where id = p_list_id for update;
  if auth.uid() is null or v_list.id is null or not private.can_read_list(p_list_id)
    or (p_owner_only and v_list.owner_id <> auth.uid()) then
    raise exception 'Lista no accesible' using errcode = '42501';
  end if;
  return v_list;
end;
$$;

create function private.save_recipe(p_recipe_id uuid, p_expected_version bigint,
  p_recipe jsonb, p_ingredients jsonb, p_steps jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_existing public.recipes; v_line jsonb; v_ord integer;
  v_ingredient_id uuid; v_custom_name text;
begin
  if auth.uid() is null then raise exception 'Sesión requerida' using errcode = '42501'; end if;
  if coalesce(jsonb_typeof(p_recipe), '') <> 'object'
    or coalesce(jsonb_typeof(p_ingredients), '') <> 'array'
    or coalesce(jsonb_typeof(p_steps), '') <> 'array' then
    raise exception 'Receta completa requerida' using errcode = '22023';
  end if;
  if jsonb_array_length(p_ingredients) not between 1 and 100
    or jsonb_array_length(p_steps) not between 1 and 100 then
    raise exception 'Ingredientes y pasos deben contener entre 1 y 100 elementos' using errcode = '22023';
  end if;
  if p_recipe_id is null then
    v_id := gen_random_uuid();
    insert into public.recipes(id, author_id, title, description, category, servings, prep_minutes, cook_minutes)
    values (v_id, auth.uid(), btrim(p_recipe->>'title'), p_recipe->>'description',
      btrim(p_recipe->>'category'), (p_recipe->>'servings')::numeric,
      (p_recipe->>'prep_minutes')::integer, (p_recipe->>'cook_minutes')::integer);
    -- New recipes are always private, even if a caller supplies visibility.
  else
    select * into v_existing from public.recipes where id = p_recipe_id for update;
    if v_existing.id is null or v_existing.author_id <> auth.uid() then
      raise exception 'Receta no accesible' using errcode = '42501';
    end if;
    if p_expected_version is null or p_expected_version <> v_existing.version then
      raise exception 'La receta ha cambiado; recarga antes de editar' using errcode = 'PT409';
    end if;
    v_id := p_recipe_id;
    update public.recipes set title = btrim(p_recipe->>'title'), description = p_recipe->>'description',
      category = btrim(p_recipe->>'category'), servings = (p_recipe->>'servings')::numeric,
      prep_minutes = (p_recipe->>'prep_minutes')::integer, cook_minutes = (p_recipe->>'cook_minutes')::integer
      where id = v_id;
    delete from public.recipe_ingredients where recipe_id = v_id;
    delete from public.recipe_steps where recipe_id = v_id;
  end if;
  for v_line, v_ord in select value, ordinality::integer - 1 from jsonb_array_elements(p_ingredients) with ordinality loop
    if coalesce(jsonb_typeof(v_line), '') <> 'object' then
      raise exception 'Ingrediente no válido' using errcode = '22023';
    end if;
    v_ingredient_id := (v_line->>'ingredient_id')::uuid;
    v_custom_name := btrim(v_line->>'custom_name');
    if (v_ingredient_id is not null) = (v_custom_name is not null) then
      raise exception 'Especifica un ingrediente de catálogo o un nombre libre' using errcode = '22023';
    end if;
    if v_ingredient_id is not null and not exists (select 1 from public.ingredients
      where id = v_ingredient_id and approved) then
      raise exception 'Ingrediente no válido' using errcode = '22023';
    end if;
    if v_ingredient_id is null then
      select a.ingredient_id into v_ingredient_id from public.ingredient_aliases a
        join public.ingredients i on i.id = a.ingredient_id
        where a.normalized_alias = private.normalize_text(v_custom_name) and i.approved;
      if v_ingredient_id is not null then v_custom_name := null; end if;
    end if;
    insert into public.recipe_ingredients(recipe_id, ingredient_id, custom_name, quantity, unit, optional, sort_order)
    values (v_id, v_ingredient_id, v_custom_name,
      (v_line->>'quantity')::numeric, btrim(v_line->>'unit'), coalesce((v_line->>'optional')::boolean, false), v_ord);
  end loop;
  for v_line, v_ord in select value, ordinality::integer - 1 from jsonb_array_elements(p_steps) with ordinality loop
    if coalesce(jsonb_typeof(v_line), '') <> 'string' then
      raise exception 'Paso no válido' using errcode = '22023';
    end if;
    insert into public.recipe_steps(recipe_id, sort_order, instruction) values (v_id, v_ord, btrim(v_line #>> '{}'));
  end loop;
  return v_id;
end;
$$;
create function public.save_recipe(p_recipe_id uuid, p_expected_version bigint,
  p_recipe jsonb, p_ingredients jsonb, p_steps jsonb) returns uuid
language sql security invoker set search_path = '' as $$
  select private.save_recipe(p_recipe_id, p_expected_version, p_recipe, p_ingredients, p_steps);
$$;

create function private.set_recipe_visibility(p_recipe_id uuid, p_visibility text, p_expected_version bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_recipe public.recipes; v_version bigint;
begin
  select * into v_recipe from public.recipes where id = p_recipe_id for update;
  if auth.uid() is null or v_recipe.id is null or v_recipe.author_id <> auth.uid() then
    raise exception 'Receta no accesible' using errcode = '42501';
  end if;
  if p_expected_version is null or p_expected_version <> v_recipe.version then
    raise exception 'La receta ha cambiado; recarga antes de publicar' using errcode = 'PT409';
  end if;
  if p_visibility is null or p_visibility not in ('private', 'public') then
    raise exception 'Visibilidad no válida' using errcode = '22023';
  end if;
  update public.recipes set visibility = p_visibility,
    published_at = case when p_visibility = 'public' then coalesce(published_at, clock_timestamp()) else published_at end
    where id = p_recipe_id returning version into v_version;
  return v_version;
end;
$$;
create function public.set_recipe_visibility(p_recipe_id uuid, p_visibility text, p_expected_version bigint)
returns bigint language sql security invoker set search_path = '' as $$
  select private.set_recipe_visibility(p_recipe_id, p_visibility, p_expected_version);
$$;

create function private.set_recipe_photo(p_recipe_id uuid, p_path text, p_expected_version bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_recipe public.recipes; v_version bigint;
begin
  select * into v_recipe from public.recipes where id = p_recipe_id for update;
  if auth.uid() is null or v_recipe.id is null or v_recipe.author_id <> auth.uid() then
    raise exception 'Receta no accesible' using errcode = '42501';
  end if;
  if p_expected_version is null or p_expected_version <> v_recipe.version then
    raise exception 'La receta ha cambiado; recarga antes de cambiar su foto' using errcode = 'PT409';
  end if;
  if p_path is not null and not exists (select 1 from storage.objects
    where bucket_id = 'recipe-photos' and name = p_path) then
    raise exception 'Fotografía no disponible' using errcode = '22023';
  end if;
  update public.recipes set hero_image_path = p_path where id = p_recipe_id returning version into v_version;
  return v_version;
end;
$$;
create function public.set_recipe_photo(p_recipe_id uuid, p_path text, p_expected_version bigint)
returns bigint language sql security invoker set search_path = '' as $$
  select private.set_recipe_photo(p_recipe_id, p_path, p_expected_version);
$$;

create function private.invite_to_list(p_list_id uuid, p_username text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_user uuid; v_invitation uuid;
begin
  perform private.require_list(p_list_id, true);
  select user_id into v_user from public.profiles where username = lower(btrim(p_username));
  if v_user is null or v_user = auth.uid() or not private.is_unblocked(v_user) then
    raise exception 'No se puede invitar a esa cuenta' using errcode = '22023';
  end if;
  if exists (select 1 from public.shopping_list_members where list_id = p_list_id and user_id = v_user) then
    raise exception 'La cuenta ya es miembro' using errcode = '22023';
  end if;
  insert into public.shopping_list_invitations(list_id, sender_id, invitee_id)
    values(p_list_id, auth.uid(), v_user) returning id into v_invitation;
  return v_invitation;
end;
$$;
create function public.invite_to_list(p_list_id uuid, p_username text) returns uuid
language sql security invoker set search_path = '' as $$ select private.invite_to_list(p_list_id, p_username); $$;

create function private.respond_to_invitation(p_invitation_id uuid, p_accept boolean) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_inv public.shopping_list_invitations; v_list public.shopping_lists;
begin
  select * into v_inv from public.shopping_list_invitations
    where id = p_invitation_id and invitee_id = auth.uid();
  if auth.uid() is null or v_inv.id is null then
    raise exception 'Invitación no accesible' using errcode = '42501';
  end if;
  -- Common lock order: list, invitation, member/items. No membership needed to accept.
  select * into v_list from public.shopping_lists where id = v_inv.list_id for update;
  select * into v_inv from public.shopping_list_invitations where id = p_invitation_id for update;
  if v_list.id is null or v_inv.id is null or v_inv.invitee_id <> auth.uid()
    or v_inv.sender_id <> v_list.owner_id or not private.is_unblocked(v_list.owner_id) then
    raise exception 'Invitación no accesible' using errcode = '42501';
  end if;
  if p_accept is null then raise exception 'Respuesta no válida' using errcode = '22023'; end if;
  if p_accept and v_inv.status = 'accepted' and exists (select 1 from public.shopping_list_members
    where list_id = v_list.id and user_id = auth.uid()) then return v_list.id; end if;
  if not p_accept and v_inv.status = 'rejected' then return v_list.id; end if;
  if v_inv.status <> 'pending' then
    raise exception 'La invitación ya no está pendiente' using errcode = '22023';
  end if;
  if p_accept then
    insert into public.shopping_list_members(list_id, user_id) values(v_list.id, auth.uid());
  end if;
  update public.shopping_list_invitations set status = case when p_accept then 'accepted' else 'rejected' end,
    responded_at = clock_timestamp() where id = p_invitation_id;
  return v_list.id;
end;
$$;
create function public.respond_to_invitation(p_invitation_id uuid, p_accept boolean) returns uuid
language sql security invoker set search_path = '' as $$ select private.respond_to_invitation(p_invitation_id, p_accept); $$;

create function private.revoke_list_member(p_list_id uuid, p_user_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_list(p_list_id, true);
  delete from public.shopping_list_members where list_id = p_list_id and user_id = p_user_id;
  update public.shopping_list_invitations set status = 'revoked', responded_at = clock_timestamp()
    where list_id = p_list_id and invitee_id = p_user_id and status in ('pending', 'accepted');
end;
$$;
create function public.revoke_list_member(p_list_id uuid, p_user_id uuid) returns void
language sql security invoker set search_path = '' as $$ select private.revoke_list_member(p_list_id, p_user_id); $$;
create function private.leave_list(p_list_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_list public.shopping_lists;
begin
  v_list := private.require_list(p_list_id);
  if v_list.owner_id = auth.uid() then raise exception 'El propietario no puede abandonar la lista' using errcode = '22023'; end if;
  delete from public.shopping_list_members where list_id = p_list_id and user_id = auth.uid();
  update public.shopping_list_invitations set status = 'revoked', responded_at = clock_timestamp()
    where list_id = p_list_id and invitee_id = auth.uid() and status = 'accepted';
end;
$$;
create function public.leave_list(p_list_id uuid) returns void
language sql security invoker set search_path = '' as $$ select private.leave_list(p_list_id); $$;

create function private.add_shopping_item(p_list_id uuid, p_item jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  perform private.require_list(p_list_id);
  if coalesce(jsonb_typeof(p_item), '') <> 'object' then raise exception 'Producto no válido' using errcode = '22023'; end if;
  if p_item->>'ingredient_id' is not null and not exists (select 1 from public.ingredients
    where id = (p_item->>'ingredient_id')::uuid and approved) then
    raise exception 'Ingrediente no válido' using errcode = '22023';
  end if;
  insert into public.shopping_items(list_id, name, ingredient_id, quantity, unit)
    values(p_list_id, btrim(p_item->>'name'), (p_item->>'ingredient_id')::uuid,
      (p_item->>'quantity')::numeric, btrim(p_item->>'unit')) returning id into v_id;
  return v_id;
end;
$$;
create function public.add_shopping_item(p_list_id uuid, p_item jsonb) returns uuid
language sql security invoker set search_path = '' as $$ select private.add_shopping_item(p_list_id, p_item); $$;

create function private.update_shopping_item(p_item_id uuid, p_expected_version bigint, p_changes jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_item public.shopping_items; v_version bigint;
begin
  select * into v_item from public.shopping_items where id = p_item_id;
  if v_item.id is null or not private.can_read_list(v_item.list_id) then
    raise exception 'Producto no accesible' using errcode = '42501';
  end if;
  perform private.require_list(v_item.list_id);
  select * into v_item from public.shopping_items where id = p_item_id for update;
  if v_item.id is null or not private.can_read_list(v_item.list_id) then
    raise exception 'Producto no accesible' using errcode = '42501';
  end if;
  if p_expected_version is null or p_expected_version <> v_item.version then
    raise exception 'El producto ha cambiado; recarga antes de editar' using errcode = 'PT409';
  end if;
  if coalesce(jsonb_typeof(p_changes), '') <> 'object' then raise exception 'Cambio no válido' using errcode = '22023'; end if;
  if exists (select 1 from jsonb_object_keys(p_changes) k where k not in ('name','quantity','unit','is_purchased')) then
    raise exception 'Campo no editable' using errcode = '22023';
  end if;
  update public.shopping_items set
    name = case when p_changes ? 'name' then btrim(p_changes->>'name') else name end,
    quantity = case when p_changes ? 'quantity' then (p_changes->>'quantity')::numeric else quantity end,
    unit = case when p_changes ? 'unit' then btrim(p_changes->>'unit') else unit end,
    is_purchased = case when p_changes ? 'is_purchased' then (p_changes->>'is_purchased')::boolean else is_purchased end
    where id = p_item_id returning version into v_version;
  return v_version;
end;
$$;
create function public.update_shopping_item(p_item_id uuid, p_expected_version bigint, p_changes jsonb)
returns bigint language sql security invoker set search_path = '' as $$
  select private.update_shopping_item(p_item_id, p_expected_version, p_changes);
$$;
create function private.delete_shopping_item(p_item_id uuid, p_expected_version bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare v_item public.shopping_items;
begin
  select * into v_item from public.shopping_items where id = p_item_id;
  if v_item.id is null or not private.can_read_list(v_item.list_id) then
    raise exception 'Producto no accesible' using errcode = '42501';
  end if;
  perform private.require_list(v_item.list_id);
  select * into v_item from public.shopping_items where id = p_item_id for update;
  if v_item.id is null or not private.can_read_list(v_item.list_id) then
    raise exception 'Producto no accesible' using errcode = '42501';
  end if;
  if p_expected_version is null or p_expected_version <> v_item.version then
    raise exception 'El producto ha cambiado; recarga antes de eliminar' using errcode = 'PT409';
  end if;
  delete from public.shopping_items where id = p_item_id;
end;
$$;
create function public.delete_shopping_item(p_item_id uuid, p_expected_version bigint) returns void
language sql security invoker set search_path = '' as $$ select private.delete_shopping_item(p_item_id, p_expected_version); $$;

create function private.import_recipe_ingredients(p_list_id uuid, p_recipe_id uuid,
  p_request_id uuid, p_ordinals integer[] default null) returns uuid[]
language plpgsql security definer set search_path = '' as $$
declare v_prior private.shopping_imports; v_hash text; v_source text; v_ids uuid[] := array[]::uuid[];
  v_line record; v_id uuid; v_recipe public.recipes;
begin
  perform private.require_list(p_list_id);
  if p_request_id is null then raise exception 'Identificador de importación requerido' using errcode = '22023'; end if;
  select * into v_recipe from public.recipes where id = p_recipe_id for share;
  if v_recipe.id is null or not private.can_read_recipe(p_recipe_id) then
    raise exception 'Receta no accesible' using errcode = '42501';
  end if;
  if p_ordinals is not null and (cardinality(p_ordinals) not between 1 and 100
    or exists (select 1 from unnest(p_ordinals) n where n is null or not exists
      (select 1 from public.recipe_ingredients ri where ri.recipe_id = p_recipe_id and ri.sort_order = n))) then
    raise exception 'Selección de ingredientes no válida' using errcode = '22023';
  end if;
  -- Canonical ordering makes a retry independent of checkbox selection order.
  if p_ordinals is not null then select array_agg(distinct n order by n) into p_ordinals from unnest(p_ordinals) n; end if;
  v_hash := encode(extensions.digest(jsonb_build_array(p_list_id, p_recipe_id, p_ordinals)::text, 'sha256'), 'hex');
  -- Serialize the same actor/request even when replayed concurrently to different lists.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || ':' || p_request_id::text, 0));
  select * into v_prior from private.shopping_imports where actor_id = auth.uid() and request_id = p_request_id;
  if v_prior.request_id is not null then
    if v_prior.payload_hash <> v_hash then raise exception 'La solicitud ya tiene otro contenido' using errcode = '22023'; end if;
    return v_prior.item_ids;
  end if;
  v_source := encode(extensions.digest(auth.uid()::text || ':' || p_request_id::text, 'sha256'), 'hex');
  for v_line in select ri.*, coalesce(i.canonical_name_es, ri.custom_name) as item_name
    from public.recipe_ingredients ri left join public.ingredients i on i.id = ri.ingredient_id
    where ri.recipe_id = p_recipe_id and (p_ordinals is null or ri.sort_order = any(p_ordinals)) order by ri.sort_order loop
    insert into public.shopping_items(list_id, name, ingredient_id, quantity, unit, source_key)
      values(p_list_id, v_line.item_name, v_line.ingredient_id, v_line.quantity, v_line.unit, v_source || ':' || v_line.sort_order)
      returning id into v_id;
    v_ids := array_append(v_ids, v_id);
  end loop;
  if cardinality(v_ids) = 0 then raise exception 'Receta sin ingredientes' using errcode = '22023'; end if;
  insert into private.shopping_imports(actor_id, request_id, list_id, payload_hash, item_ids)
    values(auth.uid(), p_request_id, p_list_id, v_hash, v_ids);
  return v_ids;
end;
$$;
create function public.import_recipe_ingredients(p_list_id uuid, p_recipe_id uuid,
  p_request_id uuid, p_ordinals integer[] default null) returns uuid[]
language sql security invoker set search_path = '' as $$
  select private.import_recipe_ingredients(p_list_id, p_recipe_id, p_request_id, p_ordinals);
$$;

create function private.submit_report(p_target_type text, p_target_id uuid, p_reason text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_access boolean := false; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Sesión requerida' using errcode = '42501'; end if;
  case p_target_type
    when 'recipe' then v_access := private.can_read_recipe(p_target_id);
    when 'comment' then select private.can_read_recipe(c.recipe_id) and private.is_unblocked(c.author_id)
      into v_access from public.recipe_comments c where c.id = p_target_id;
    when 'profile' then select private.is_unblocked(p.user_id) into v_access from public.profiles p where p.user_id = p_target_id;
    else raise exception 'Tipo de contenido no válido' using errcode = '22023';
  end case;
  if not coalesce(v_access, false) then raise exception 'Contenido no accesible' using errcode = '42501'; end if;
  insert into public.content_reports(reporter_id, target_type, target_id, reason)
    values(auth.uid(), p_target_type, p_target_id, btrim(p_reason)) returning id into v_id;
  return v_id;
end;
$$;
create function public.submit_report(p_target_type text, p_target_id uuid, p_reason text) returns uuid
language sql security invoker set search_path = '' as $$ select private.submit_report(p_target_type, p_target_id, p_reason); $$;

-- No implicit PUBLIC EXECUTE, including trigger functions and lock helpers.
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.normalize_text(text), private.is_unblocked(uuid),
  private.owns_recipe(uuid), private.can_read_recipe(uuid), private.can_interact_recipe(uuid),
  private.owns_list(uuid), private.can_read_list(uuid) to authenticated;
do $$
declare f record;
begin
  for f in select n.nspname, p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.proname in
      ('save_recipe','set_recipe_visibility','set_recipe_photo','invite_to_list',
       'respond_to_invitation','revoke_list_member','leave_list','add_shopping_item',
       'update_shopping_item','delete_shopping_item','import_recipe_ingredients','submit_report') loop
    execute format('revoke all on function %s from public, anon, authenticated', f.signature);
    execute format('grant execute on function %s to authenticated', f.signature);
  end loop;
end;
$$;
