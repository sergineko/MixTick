-- Phase 05: bounded projections run as the caller. RLS applies to recipes,
-- profiles, ingredients AND social counts. No privileged aggregate/view.
alter table public.recipe_comments add constraint comment_non_whitespace
  check (char_length(btrim(private.normalize_text(content)))>0);
create function public.community_page(
  p_search text default '', p_category text default null,
  p_author text default null, p_saved boolean default false,
  p_before timestamptz default null, p_before_id uuid default null,
  p_limit integer default 9, p_recipe_id uuid default null
) returns setof jsonb language plpgsql stable security invoker set search_path = '' as $$
declare v_query text := private.normalize_text(coalesce(p_search,''));
begin
  if auth.uid() is null then raise exception 'Sesión requerida' using errcode='42501'; end if;
  if char_length(v_query)>120 or p_limit is null or p_limit not between 1 and 50
    or (p_before is null) <> (p_before_id is null) then
    raise exception 'Consulta no válida' using errcode='22023';
  end if;
  return query
  with page as materialized (
    select r.*, p.username, p.display_name, p.avatar_path
    from public.recipes r join public.profiles p on p.user_id=r.author_id
    where r.visibility='public'
      and (p_recipe_id is null or r.id=p_recipe_id)
      and (p_category is null or r.category=p_category)
      and (p_author is null or p.username=lower(btrim(p_author)))
      and (not coalesce(p_saved,false) or exists(select 1 from public.recipe_saves s where s.recipe_id=r.id))
      and (p_before is null or (r.published_at,r.id)<(p_before,p_before_id))
      and (v_query='' or strpos(private.normalize_text(r.title),v_query)>0
        or strpos(private.normalize_text(r.category),v_query)>0
        or exists(select 1 from public.recipe_ingredients ri
          where ri.recipe_id=r.id and (ri.custom_key=v_query or ri.ingredient_id in (
            select a.ingredient_id from public.ingredient_aliases a
              join public.ingredients i on i.id=a.ingredient_id
              where a.normalized_alias=v_query and i.approved))))
    order by r.published_at desc,r.id desc limit p_limit
  )
  select jsonb_build_object(
    'recipe',jsonb_build_object('id',r.id,'author_id',r.author_id,'title',r.title,
      'description',r.description,'category',r.category,'servings',r.servings,
      'prep_minutes',r.prep_minutes,'cook_minutes',r.cook_minutes,'visibility',r.visibility,
      'hero_image_path',r.hero_image_path,'version',r.version,'updated_at',r.updated_at),
    'author',jsonb_build_object('username',r.username,'display_name',r.display_name,'avatar_path',r.avatar_path),
    'published_at',r.published_at,
    'likes',(select count(*) from public.recipe_likes l where l.recipe_id=r.id),
    'comments',(select count(*) from public.recipe_comments c where c.recipe_id=r.id),
    'liked',exists(select 1 from public.recipe_likes l where l.recipe_id=r.id and l.user_id=auth.uid()),
    'saved',exists(select 1 from public.recipe_saves s where s.recipe_id=r.id)
  ) from page r order by r.published_at desc,r.id desc;
end;
$$;

create function public.community_categories() returns setof text
language sql stable security invoker set search_path = '' as $$
  select distinct r.category from public.recipes r join public.profiles p on p.user_id=r.author_id
  where r.visibility='public' order by r.category;
$$;
create function public.community_author(p_username text) returns jsonb
language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object('id',p.user_id,
    'profile',jsonb_build_object('username',p.username,'display_name',p.display_name,'avatar_path',p.avatar_path),
    'followers',(select count(*) from public.user_follows f where f.followed_id=p.user_id),
    'following',(select count(*) from public.user_follows f where f.follower_id=p.user_id),
    'followed',exists(select 1 from public.user_follows f where f.followed_id=p.user_id and f.follower_id=auth.uid()))
  from public.profiles p where p.username=lower(btrim(p_username));
$$;

-- Retrying a comment after a lost response reuses its UUID, without consuming
-- another creation quota or duplicating content. Historical direct INSERT stays.
-- Requests are scoped to the actor, so a supplied UUID cannot probe a foreign
-- comment's existence. A deleted comment leaves a tombstone, never resurrects.
create table private.comment_creation_requests (
  actor_id uuid not null references public.profiles(user_id) on delete cascade,
  request_id uuid not null,
  payload_hash text not null,
  comment_id uuid references public.recipe_comments(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key(actor_id,request_id)
);
alter table private.comment_creation_requests enable row level security;
revoke all on private.comment_creation_requests from public,anon,authenticated;
create function private.create_comment_once(p_id uuid,p_recipe_id uuid,p_content text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_prior private.comment_creation_requests; v_recipe public.recipes;
  v_hash text; v_id uuid;
begin
  select * into v_recipe from public.recipes where id=p_recipe_id for share;
  if auth.uid() is null or v_recipe.id is null or not private.can_interact_recipe(p_recipe_id) then
    raise exception 'Contenido no accesible' using errcode='42501';
  end if;
  if p_id is null or p_content is null or char_length(btrim(p_content)) not between 1 and 2000 then
    raise exception 'Comentario no válido' using errcode='22023';
  end if;
  v_hash := encode(extensions.digest(jsonb_build_array(p_recipe_id,btrim(p_content))::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || ':' || p_id::text || ':comment',0));
  select * into v_prior from private.comment_creation_requests where actor_id=auth.uid() and request_id=p_id;
  if found then
    if v_prior.comment_id is null or v_prior.payload_hash<>v_hash then
      raise exception 'Solicitud no disponible' using errcode='PT409';
    end if;
    return v_prior.comment_id;
  end if;
  v_id := gen_random_uuid();
  insert into public.recipe_comments(id,recipe_id,author_id,content)
    values(v_id,p_recipe_id,auth.uid(),btrim(p_content));
  insert into private.comment_creation_requests(actor_id,request_id,payload_hash,comment_id)
    values(auth.uid(),p_id,v_hash,v_id);
  return v_id;
end;
$$;
create function public.create_comment_once(p_id uuid,p_recipe_id uuid,p_content text) returns uuid
language sql security invoker set search_path = '' as $$
  select private.create_comment_once(p_id,p_recipe_id,p_content);
$$;
create index recipes_public_chronological on public.recipes(published_at desc,id desc) where visibility='public';
revoke all on function public.community_page(text,text,text,boolean,timestamptz,uuid,integer,uuid),
  public.community_categories(), public.community_author(text),
  private.create_comment_once(uuid,uuid,text),public.create_comment_once(uuid,uuid,text)
  from public,anon,authenticated;
grant execute on function public.community_page(text,text,text,boolean,timestamptz,uuid,integer,uuid),
  public.community_categories(), public.community_author(text),
  private.create_comment_once(uuid,uuid,text),public.create_comment_once(uuid,uuid,text) to authenticated;
