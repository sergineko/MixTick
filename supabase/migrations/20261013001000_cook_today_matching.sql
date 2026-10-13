-- Phase 06: read-only presence matching, as the authenticated caller under RLS.
-- No pantry, recipe copies, privileged projection or mutation.
create index recipe_ingredients_free_match on public.recipe_ingredients(custom_key,recipe_id)
  where custom_key is not null;

create function public.cook_today_page(
  p_ids uuid[] default '{}', p_names text[] default '{}',
  p_mode text default 'exact', p_after jsonb default null, p_limit integer default 9
) returns setof jsonb language plpgsql stable security invoker set search_path = '' as $$
declare v_ids uuid[]; v_free text[]; v_missing integer; v_rank integer;
  v_minutes integer; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Sesión requerida' using errcode='42501'; end if;
  if p_ids is null or p_names is null or cardinality(p_ids)+cardinality(p_names)>50
    or p_mode is null or p_mode not in ('exact','near')
    or p_limit is null or p_limit not between 1 and 50
    or exists(select 1 from unnest(p_names) n where n is null or char_length(n)>80
      or char_length(btrim(private.normalize_text(n)))=0)
    or exists(select 1 from unnest(p_ids) n where n is null or not exists(
      select 1 from public.ingredients i where i.id=n and i.approved)) then
    raise exception 'Selección no válida' using errcode='22023';
  end if;
  if p_after is not null then
    if jsonb_typeof(p_after)<>'object' then
      raise exception 'Cursor no válido' using errcode='22023';
    end if;
    if not p_after ?& array['missing','rank','minutes','id'] or
      exists(select 1 from jsonb_object_keys(p_after) k where k not in ('missing','rank','minutes','id')) then
      raise exception 'Cursor no válido' using errcode='22023';
    end if;
    v_missing := (p_after->>'missing')::integer;
    v_rank := (p_after->>'rank')::integer;
    v_minutes := (p_after->>'minutes')::integer;
    v_id := (p_after->>'id')::uuid;
    if v_missing is null or v_missing not between 0 and 2 or v_rank is null
      or v_rank not between -100 and 0 or v_minutes is null or v_minutes not between 0 and 20161
      or v_id is null then raise exception 'Cursor no válido' using errcode='22023'; end if;
  end if;
  -- Resolve the full registered alias only, including names submitted as free text.
  select coalesce(array_agg(distinct id),'{}'::uuid[]) into v_ids from (
    select unnest(p_ids) id union all
    select a.ingredient_id from unnest(p_names) n
      join public.ingredient_aliases a on a.normalized_alias=btrim(private.normalize_text(n))
      join public.ingredients i on i.id=a.ingredient_id and i.approved
  ) selected;
  select coalesce(array_agg(distinct btrim(private.normalize_text(n))),'{}'::text[])
    into v_free from unnest(p_names) n where not exists (
      select 1 from public.ingredient_aliases a join public.ingredients i on i.id=a.ingredient_id and i.approved
      where a.normalized_alias=btrim(private.normalize_text(n)));
  if cardinality(v_ids)+cardinality(v_free)=0 then return; end if;
  return query
  with candidates as materialized (
    -- At least one matching REQUIRED key. Existing FK and new free-key indexes
    -- support the candidate set; unrelated/optional-only recipes are not scored.
    select distinct ri.recipe_id from public.recipe_ingredients ri
    left join public.ingredient_aliases a on a.normalized_alias=ri.custom_key
    left join public.ingredients known on known.id=a.ingredient_id and known.approved
    where not ri.optional and (
      coalesce(ri.ingredient_id,known.id)=any(v_ids) or
      (coalesce(ri.ingredient_id,known.id) is null and ri.custom_key=any(v_free)))
  ), lines as materialized (
    select ri.*, coalesce(ri.ingredient_id,known.id) effective_id,
      coalesce(i.canonical_name_es,ri.custom_name) item_name,
      coalesce(ri.ingredient_id::text,known.id::text,'free:'||ri.custom_key) match_key,
      coalesce(coalesce(ri.ingredient_id,known.id)=any(v_ids),false) or
        (coalesce(ri.ingredient_id,known.id) is null and ri.custom_key=any(v_free)) present
    from candidates c join public.recipe_ingredients ri on ri.recipe_id=c.recipe_id
    left join public.ingredients i on i.id=ri.ingredient_id
    left join public.ingredient_aliases a on a.normalized_alias=ri.custom_key
    left join public.ingredients known on known.id=a.ingredient_id and known.approved
  ), keys as (
    select recipe_id,match_key,bool_and(optional) optional,bool_or(present) present
    from lines group by recipe_id,match_key
  ), counts as (
    select recipe_id,count(*) filter(where not optional)::integer required,
      count(*) filter(where not optional and present)::integer matched,
      count(*) filter(where not optional and not present)::integer missing,
      count(*) filter(where optional and present)::integer optional_matched
    from keys group by recipe_id
  ), scored as (
    select r.*,p.username,p.display_name,p.avatar_path,c.required,c.matched,c.missing,c.optional_matched,
      case when c.missing=0 then -c.optional_matched else -c.matched end rank,
      case when r.prep_minutes is null and r.cook_minutes is null then 20161
        else coalesce(r.prep_minutes,0)+coalesce(r.cook_minutes,0) end minutes
    from counts c join public.recipes r on r.id=c.recipe_id
      join public.profiles p on p.user_id=r.author_id
    where c.required>0 and c.matched>0 and
      ((p_mode='exact' and c.missing=0) or (p_mode='near' and c.missing<=2))
  ), page as materialized (
    select * from scored r where p_after is null or
      (r.missing,r.rank,r.minutes,r.id)>(v_missing,v_rank,v_minutes,v_id)
    order by r.missing,r.rank,r.minutes,r.id limit p_limit
  )
  select jsonb_build_object(
    'recipe',jsonb_build_object('id',r.id,'author_id',r.author_id,'title',r.title,
      'description',r.description,'category',r.category,'servings',r.servings,
      'prep_minutes',r.prep_minutes,'cook_minutes',r.cook_minutes,'visibility',r.visibility,
      'hero_image_path',r.hero_image_path,'version',r.version,'updated_at',r.updated_at),
    'author',jsonb_build_object('username',r.username,'display_name',r.display_name,'avatar_path',r.avatar_path),
    'required',r.required,'matched',r.matched,'missing',r.missing,'optional_matched',r.optional_matched,
    'cursor',jsonb_build_object('missing',r.missing,'rank',r.rank,'minutes',r.minutes,'id',r.id),
    'missing_ingredients',coalesce((select jsonb_agg(jsonb_build_object(
      'line_id',l.id,'sort_order',l.sort_order,'effective_id',l.effective_id,
      'ingredient_id',l.ingredient_id,'custom_name',l.custom_name,
      'ingredients',jsonb_build_object('canonical_name_es',l.item_name),
      'quantity',l.quantity,'unit',l.unit,'optional',l.optional) order by l.sort_order)
      from lines l where l.recipe_id=r.id and not l.optional and not l.present),'[]'::jsonb)
  ) from page r order by r.missing,r.rank,r.minutes,r.id;
end;
$$;
revoke all on function public.cook_today_page(uuid[],text[],text,jsonb,integer) from public,anon,authenticated;
grant execute on function public.cook_today_page(uuid[],text[],text,jsonb,integer) to authenticated;
