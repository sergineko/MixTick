-- Transverse operational tooling; no mobile admin tab or metadata-based roles.
create table private.moderation_operators (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  created_at timestamptz not null default clock_timestamp()
);
create table private.moderation_restrictions (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  created_at timestamptz not null default clock_timestamp()
);
create table private.moderation_hidden_recipes (
  recipe_id uuid primary key references public.recipes(id) on delete cascade,
  created_at timestamptz not null default clock_timestamp()
);
create table private.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid references public.profiles(user_id) on delete set null,
  report_id uuid references public.content_reports(id) on delete set null,
  target_type text,
  target_id uuid,
  action text not null check(action in ('review','close','hide_recipe','restore_recipe','remove_comment','restrict_profile','restore_profile')),
  created_at timestamptz not null default clock_timestamp()
);
alter table private.moderation_operators enable row level security;
alter table private.moderation_restrictions enable row level security;
alter table private.moderation_actions enable row level security;
alter table private.moderation_hidden_recipes enable row level security;
revoke all on private.moderation_operators,private.moderation_restrictions,private.moderation_actions,private.moderation_hidden_recipes from public,anon,authenticated;
create function private.public_author_visible(p_user_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select p_user_id=(select auth.uid()) or not exists(select 1 from private.moderation_restrictions r where r.user_id=p_user_id);
$$;
revoke all on function private.public_author_visible(uuid) from public,anon,authenticated;
grant execute on function private.public_author_visible(uuid) to authenticated;
create policy moderated_profile on public.profiles as restrictive for select to authenticated
  using (private.public_author_visible(user_id));
create policy moderated_recipe on public.recipes as restrictive for select to authenticated
  using (private.public_author_visible(author_id));
create policy moderated_comment on public.recipe_comments as restrictive for select to authenticated
  using (private.public_author_visible(author_id));
create policy moderated_like on public.recipe_likes as restrictive for select to authenticated
  using (private.public_author_visible(user_id));
create policy moderated_follow on public.user_follows as restrictive for select to authenticated
  using (private.public_author_visible(follower_id) and private.public_author_visible(followed_id));
create or replace function private.can_read_recipe(recipe uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.actor_active() and exists(select 1 from public.recipes r where r.id=recipe and
    (r.author_id=auth.uid() or (r.visibility='public' and private.is_unblocked(r.author_id)
      and private.public_author_visible(r.author_id))));
$$;
create or replace function private.avatar_access(p_name text,p_write boolean) returns boolean
language sql stable security definer set search_path='' as $$
  select private.actor_active() and p_name ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'
    and exists(select 1 from public.profiles p where p.user_id::text=split_part(p_name,'/',1) and
      (p.user_id=auth.uid() or (not p_write and p.avatar_path=p_name
        and private.is_unblocked(p.user_id) and private.public_author_visible(p.user_id))));
$$;
create function private.enforce_content_restriction() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_table_name='recipes' then
    if new.visibility='public' and exists(
      select 1 from private.moderation_hidden_recipes h where h.recipe_id=new.id) then
      raise exception 'Publicación restringida' using errcode='42501'; end if;
  end if;
  if exists(select 1 from private.moderation_restrictions r where r.user_id=new.author_id) then
    if tg_table_name='recipe_comments' then
      raise exception 'Participación restringida' using errcode='42501';
    elsif new.visibility='public' then
      raise exception 'Publicación restringida' using errcode='42501';
    end if;
  end if;
  return new;
end;
$$;
create trigger content_restriction before insert or update of visibility on public.recipes
  for each row execute function private.enforce_content_restriction();
create trigger content_restriction before insert or update of content on public.recipe_comments
  for each row execute function private.enforce_content_restriction();
create function private.require_moderator() returns void
language plpgsql stable security definer set search_path='' as $$
begin
  if not private.actor_active() or not exists(select 1 from private.moderation_operators where user_id=auth.uid()) then
    raise exception 'Operación no autorizada' using errcode='42501'; end if;
end;
$$;
create function private.moderation_reports(p_limit integer default 20,p_after uuid default null) returns setof jsonb
language plpgsql stable security definer set search_path='' as $$
declare report public.content_reports; preview jsonb;
begin
  perform private.require_moderator();
  if p_limit is null or p_limit not between 1 and 50 then raise exception 'Límite no válido' using errcode='22023'; end if;
  for report in select * from public.content_reports where p_after is null or id>p_after order by id limit p_limit loop
    preview:=null;
    if report.target_type='recipe' then
      select jsonb_build_object('title',r.title,'description',r.description) into preview
        from public.recipes r where r.id=report.target_id and r.visibility='public';
    elsif report.target_type='comment' then
      select jsonb_build_object('content',c.content) into preview from public.recipe_comments c
        join public.recipes r on r.id=c.recipe_id where c.id=report.target_id and r.visibility='public';
    else
      select jsonb_build_object('username',p.username,'display_name',p.display_name) into preview
        from public.profiles p where p.user_id=report.target_id;
    end if;
    return next jsonb_build_object('id',report.id,'target_type',report.target_type,'target_id',report.target_id,
      'reason',report.reason,'status',report.status,'created_at',report.created_at,
      'public_preview',preview,'private_content_redacted',preview is null);
  end loop;
end;
$$;
create function public.moderation_reports(p_limit integer default 20,p_after uuid default null) returns setof jsonb
language sql stable security invoker set search_path='' as $$ select private.moderation_reports(p_limit,p_after); $$;
create function private.moderate_report(p_report_id uuid,p_expected_status text,p_action text) returns uuid
language plpgsql security definer set search_path='' as $$
declare report public.content_reports; action_id uuid;
begin
  perform private.require_moderator();
  select * into report from public.content_reports where id=p_report_id for update;
  if not found then raise exception 'Informe no disponible' using errcode='42501'; end if;
  if p_expected_status is null or p_expected_status<>report.status then raise exception 'Informe modificado' using errcode='PT409'; end if;
  if p_action is null or p_action not in ('review','close','hide_recipe','restore_recipe','remove_comment','restrict_profile','restore_profile') then
    raise exception 'Acción no válida' using errcode='22023'; end if;
  if p_action='hide_recipe' then
    if report.target_type<>'recipe' then raise exception 'Acción no válida' using errcode='22023'; end if;
    insert into private.moderation_hidden_recipes(recipe_id) values(report.target_id) on conflict do nothing;
    update public.recipes set visibility='private' where id=report.target_id;
  elsif p_action='restore_recipe' then
    if report.target_type<>'recipe' then raise exception 'Acción no válida' using errcode='22023'; end if;
    delete from private.moderation_hidden_recipes where recipe_id=report.target_id;
  elsif p_action='restore_profile' then
    if report.target_type<>'profile' then raise exception 'Acción no válida' using errcode='22023'; end if;
    delete from private.moderation_restrictions where user_id=report.target_id;
  elsif p_action='remove_comment' then
    if report.target_type<>'comment' then raise exception 'Acción no válida' using errcode='22023'; end if;
    delete from public.recipe_comments where id=report.target_id;
  elsif p_action='restrict_profile' then
    if report.target_type<>'profile' or report.target_id=auth.uid() or exists(
      select 1 from private.moderation_operators where user_id=report.target_id) then
      raise exception 'Acción no válida' using errcode='22023'; end if;
    insert into private.moderation_restrictions(user_id) values(report.target_id) on conflict do nothing;
    update public.recipes set visibility='private' where author_id=report.target_id and visibility='public';
  end if;
  update public.content_reports set status=case when p_action='review' then 'reviewed' else 'closed' end where id=report.id;
  insert into private.moderation_actions(operator_id,report_id,target_type,target_id,action)
    values(auth.uid(),report.id,report.target_type,report.target_id,p_action) returning id into action_id;
  return action_id;
end;
$$;
create function public.moderate_report(p_report_id uuid,p_expected_status text,p_action text) returns uuid
language sql security invoker set search_path='' as $$ select private.moderate_report(p_report_id,p_expected_status,p_action); $$;
create function private.minimize_moderation_identity() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  update private.moderation_actions set target_id=null,target_type=null where
    (target_type='profile' and target_id=old.user_id) or
    (target_type='recipe' and target_id in(select id from public.recipes where author_id=old.user_id)) or
    (target_type='comment' and target_id in(select id from public.recipe_comments where author_id=old.user_id));
  return old;
end;
$$;
create trigger minimize_moderation_identity before delete on public.profiles
  for each row execute function private.minimize_moderation_identity();
create or replace function private.maintain_private_operations() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  delete from private.storage_cleanup_jobs where state='done' and finished_at<clock_timestamp()-interval '30 days'
    and not exists(select 1 from storage.objects o where o.bucket_id=storage_cleanup_jobs.bucket_id and o.name=storage_cleanup_jobs.object_name);
  delete from private.storage_cleanup_jobs where state='dead' and not fenced and finished_at<clock_timestamp()-interval '30 days';
  delete from private.account_deletions where state='done' and finished_at<clock_timestamp()-interval '30 days';
  delete from private.moderation_actions where created_at<clock_timestamp()-interval '30 days';
  delete from public.content_reports where created_at<clock_timestamp()-interval '30 days';
  return jsonb_build_object('storage_pending',(select count(*) from private.storage_cleanup_jobs where state in ('queued','working')),
    'storage_failed',(select count(*) from private.storage_cleanup_jobs where state='dead'),
    'accounts_pending',(select count(*) from private.account_deletions where state in ('queued','working')),
    'accounts_failed',(select count(*) from private.account_deletions where state='dead'));
end;
$$;
revoke all on function private.enforce_content_restriction(),private.require_moderator(),private.minimize_moderation_identity() from public,anon,authenticated;
do $$ declare f record; begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.proname in ('moderation_reports','moderate_report') loop
    execute format('revoke all on function %s from public,anon,authenticated',f.signature);
    execute format('grant execute on function %s to authenticated',f.signature);
  end loop;
end $$;
