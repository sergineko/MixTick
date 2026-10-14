-- Phase 07: preserve 001-010 and every historical shopping entry point.
-- This private ledger binds a retry to its actor, operation and reviewed payload.
-- IDs survive deletion as tombstones; no client can read recipe provenance here.
create table private.shopping_requests (
  actor_id uuid not null references public.profiles(user_id) on delete cascade,
  request_id uuid not null,
  kind text not null check(kind in ('list','item','import')),
  payload_hash text not null,
  result_ids uuid[] not null,
  created_at timestamptz not null default now(),
  primary key(actor_id,request_id)
);
alter table private.shopping_requests enable row level security;
revoke all on private.shopping_requests from public,anon,authenticated;

create function private.create_shopping_list_once(p_request_id uuid,p_title text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_prior private.shopping_requests; v_hash text; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Sesión requerida' using errcode='42501'; end if;
  if p_request_id is null or p_title is null or char_length(btrim(p_title)) not between 1 and 120 then
    raise exception 'Título no válido' using errcode='22023'; end if;
  v_hash := encode(extensions.digest(jsonb_build_array('list',btrim(p_title))::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':shopping:'||p_request_id::text,0));
  select * into v_prior from private.shopping_requests where actor_id=auth.uid() and request_id=p_request_id;
  if found then
    if v_prior.kind<>'list' or v_prior.payload_hash<>v_hash then raise exception 'Solicitud distinta' using errcode='PT409'; end if;
    if not private.owns_list(v_prior.result_ids[1]) then raise exception 'Lista eliminada' using errcode='PT409'; end if;
    return v_prior.result_ids[1];
  end if;
  insert into public.shopping_lists(owner_id,title) values(auth.uid(),btrim(p_title)) returning id into v_id;
  insert into private.shopping_requests values(auth.uid(),p_request_id,'list',v_hash,array[v_id],now());
  return v_id;
end;
$$;
create function public.create_shopping_list_once(p_request_id uuid,p_title text) returns uuid
language sql security invoker set search_path='' as $$ select private.create_shopping_list_once(p_request_id,p_title); $$;

create function private.add_shopping_item_once(p_list_id uuid,p_request_id uuid,p_item jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_prior private.shopping_requests; v_hash text; v_id uuid;
begin
  perform private.require_list(p_list_id);
  if p_request_id is null or coalesce(jsonb_typeof(p_item),'')<>'object' or exists(
    select 1 from jsonb_object_keys(p_item) k where k not in ('name','ingredient_id','quantity','unit')) then
    raise exception 'Producto no válido' using errcode='22023'; end if;
  v_hash := encode(extensions.digest(jsonb_build_array('item',p_list_id,p_item)::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':shopping:'||p_request_id::text,0));
  select * into v_prior from private.shopping_requests where actor_id=auth.uid() and request_id=p_request_id;
  if found then
    if v_prior.kind<>'item' or v_prior.payload_hash<>v_hash then raise exception 'Solicitud distinta' using errcode='PT409'; end if;
    if not exists(select 1 from public.shopping_items where id=v_prior.result_ids[1] and list_id=p_list_id) then
      raise exception 'Producto eliminado' using errcode='PT409'; end if;
    return v_prior.result_ids[1];
  end if;
  v_id := private.add_shopping_item(p_list_id,p_item);
  insert into private.shopping_requests values(auth.uid(),p_request_id,'item',v_hash,array[v_id],now());
  return v_id;
end;
$$;
create function public.add_shopping_item_once(p_list_id uuid,p_request_id uuid,p_item jsonb) returns uuid
language sql security invoker set search_path='' as $$ select private.add_shopping_item_once(p_list_id,p_request_id,p_item); $$;

-- One RLS-protected snapshot: no mixed versions, N+1 component requests or steps.
create function public.shopping_recipe_preview(p_recipe_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
  select jsonb_build_object('recipe_id',r.id,'version',r.version,'title',r.title,'servings',r.servings,
    'lines',coalesce((select jsonb_agg(jsonb_build_object('line_id',ri.id,'sort_order',ri.sort_order,
      'ingredient_id',ri.ingredient_id,'custom_name',ri.custom_name,'quantity',ri.quantity,'unit',ri.unit,
      'optional',ri.optional,'ingredients',jsonb_build_object('canonical_name_es',coalesce(i.canonical_name_es,ri.custom_name)))
      order by ri.sort_order) from public.recipe_ingredients ri left join public.ingredients i on i.id=ri.ingredient_id
      where ri.recipe_id=r.id),'[]'::jsonb)) from public.recipes r where r.id=p_recipe_id;
$$;

create function private.import_recipe_checked(p_list_id uuid,p_recipe_id uuid,p_expected_version bigint,
  p_request_id uuid,p_line_ids uuid[],p_ordinals integer[],p_missing_only boolean default false) returns uuid[]
language plpgsql security definer set search_path='' as $$
declare v_recipe public.recipes; v_prior private.shopping_requests; v_hash text; v_pairs jsonb; v_ids uuid[];
begin
  perform private.require_list(p_list_id);
  select * into v_recipe from public.recipes where id=p_recipe_id for share;
  if v_recipe.id is null or not private.can_read_recipe(p_recipe_id) then
    raise exception 'Receta no accesible' using errcode='42501'; end if;
  if p_request_id is null or p_expected_version is null or p_missing_only is null
    or p_line_ids is null or p_ordinals is null or cardinality(p_line_ids) not between 1 and 100
    or cardinality(p_line_ids)<>cardinality(p_ordinals)
    or exists(select 1 from unnest(p_line_ids,p_ordinals) x(id,ordinal) where id is null or ordinal is null)
    or (select count(distinct id) from unnest(p_line_ids) id)<>cardinality(p_line_ids)
    or (select count(distinct ordinal) from unnest(p_ordinals) ordinal)<>cardinality(p_ordinals) then
    raise exception 'Selección no válida' using errcode='22023'; end if;
  select jsonb_agg(jsonb_build_array(id,ordinal) order by ordinal) into v_pairs from unnest(p_line_ids,p_ordinals) x(id,ordinal);
  v_hash := encode(extensions.digest(jsonb_build_array('import',p_list_id,p_recipe_id,p_expected_version,v_pairs,p_missing_only)::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':shopping:'||p_request_id::text,0));
  select * into v_prior from private.shopping_requests where actor_id=auth.uid() and request_id=p_request_id;
  if found then
    if v_prior.kind<>'import' or v_prior.payload_hash<>v_hash then raise exception 'Solicitud distinta' using errcode='PT409'; end if;
    return v_prior.result_ids; -- Recheck permissions above, never recreate or uncheck a product.
  end if;
  if exists(select 1 from private.shopping_imports where actor_id=auth.uid() and request_id=p_request_id) then
    raise exception 'Solicitud histórica distinta' using errcode='PT409'; end if;
  if v_recipe.version<>p_expected_version or exists(select 1 from unnest(p_line_ids,p_ordinals) x(id,ordinal)
    where not exists(select 1 from public.recipe_ingredients ri where ri.recipe_id=p_recipe_id and ri.id=x.id
      and ri.sort_order=x.ordinal and (not p_missing_only or not ri.optional))) then
    raise exception 'La receta ha cambiado; revisa los ingredientes' using errcode='PT409'; end if;
  v_ids := private.import_recipe_ingredients(p_list_id,p_recipe_id,p_request_id,p_ordinals);
  insert into private.shopping_requests values(auth.uid(),p_request_id,'import',v_hash,v_ids,now());
  return v_ids;
end;
$$;
create function public.import_recipe_checked(p_list_id uuid,p_recipe_id uuid,p_expected_version bigint,
  p_request_id uuid,p_line_ids uuid[],p_ordinals integer[],p_missing_only boolean default false) returns uuid[]
language sql security invoker set search_path='' as $$
  select private.import_recipe_checked(p_list_id,p_recipe_id,p_expected_version,p_request_id,p_line_ids,p_ordinals,p_missing_only);
$$;

-- An explicit pending invitation conveys its list title and public sender name,
-- never list products/members or access to the list. Blocks still apply both ways.
create function private.shopping_invitation_inbox() returns setof jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',i.id,'list_id',i.list_id,'title',l.title,'sender',p.username,
    'invitee_id',i.invitee_id) from public.shopping_list_invitations i
    join public.shopping_lists l on l.id=i.list_id and l.owner_id=i.sender_id
    join public.profiles p on p.user_id=i.sender_id
    where auth.uid() is not null and i.invitee_id=auth.uid() and i.status='pending'
      and private.is_unblocked(i.sender_id) and private.is_unblocked(i.invitee_id)
    order by i.created_at desc,i.id;
$$;
create function public.shopping_invitation_inbox() returns setof jsonb
language sql stable security invoker set search_path='' as $$ select private.shopping_invitation_inbox(); $$;

-- A single statement revalidates the parent and all children under caller RLS.
create function public.shopping_list_snapshot(p_list_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
  select jsonb_build_object('list',to_jsonb(l),'items',coalesce((select jsonb_agg(to_jsonb(i)
    order by i.is_purchased,i.created_at,i.id) from public.shopping_items i where i.list_id=l.id),'[]'::jsonb),
    'members',coalesce((select jsonb_agg(jsonb_build_object('user_id',m.user_id,'username',p.username)
      order by m.joined_at,m.user_id) from public.shopping_list_members m
      left join public.profiles p on p.user_id=m.user_id where m.list_id=l.id),'[]'::jsonb),
    'invitations',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'list_id',i.list_id,
      'invitee_id',i.invitee_id,'username',p.username,'status',i.status) order by i.created_at,i.id)
      from public.shopping_list_invitations i left join public.profiles p on p.user_id=i.invitee_id
      where i.list_id=l.id and i.status='pending'),'[]'::jsonb)) from public.shopping_lists l where l.id=p_list_id;
$$;

do $$
declare f record;
begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.proname in ('create_shopping_list_once','add_shopping_item_once',
      'shopping_recipe_preview','import_recipe_checked','shopping_invitation_inbox','shopping_list_snapshot') loop
    execute format('revoke all on function %s from public,anon,authenticated',f.signature);
    execute format('grant execute on function %s to authenticated',f.signature);
  end loop;
end;
$$;
