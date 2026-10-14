-- Auth, PostgreSQL and Storage do not share a distributed transaction.
-- Withdraw product data atomically, fence access, then remove physical objects
-- and Auth via the server worker. Durable jobs reconcile interrupted requests.
create table private.account_deletions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid unique,
  actor_hash text not null,
  request_id uuid not null,
  state text not null default 'queued' check(state in ('queued','working','done','dead')),
  attempts integer not null default 0 check(attempts between 0 and 5),
  claim_id uuid,
  lease_until timestamptz,
  not_before timestamptz not null default clock_timestamp(),
  created_at timestamptz not null default clock_timestamp(),
  finished_at timestamptz,
  error_code text check(error_code in ('auth_failure','foreign_storage')),
  check((state='done')=(actor_id is null))
);
alter table private.account_deletions enable row level security;
revoke all on private.account_deletions from public,anon,authenticated;
create function private.actor_active() returns boolean
language sql stable security definer set search_path='' as $$
  select (select auth.uid()) is not null
    and exists(select 1 from auth.users u where u.id=(select auth.uid()))
    and not exists(select 1 from private.account_deletions d where d.actor_id=(select auth.uid()));
$$;
revoke all on function private.actor_active() from public,anon,authenticated;
grant execute on function private.actor_active() to authenticated;
-- Restrictive AND applies to reads and direct writes even with an old valid JWT.
do $$ declare t record; begin
  for t in select tablename from pg_tables where schemaname='public' loop
    execute format('create policy active_account on public.%I as restrictive for all to authenticated using ((select private.actor_active())) with check ((select private.actor_active()))',t.tablename);
  end loop;
end $$;
create policy active_account on storage.objects as restrictive for all to authenticated
  using ((select private.actor_active())) with check ((select private.actor_active()));

-- Existing definer operations do not evaluate table RLS. Their authorization
-- helpers must also reject deleted/deleting identities.
create or replace function private.is_unblocked(other_user uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.actor_active() and not exists(select 1 from public.user_blocks b where
    (b.blocker_id=auth.uid() and b.blocked_id=other_user) or
    (b.blocked_id=auth.uid() and b.blocker_id=other_user));
$$;
create or replace function private.owns_recipe(recipe uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.actor_active() and exists(select 1 from public.recipes r where r.id=recipe and r.author_id=auth.uid());
$$;
create or replace function private.can_read_recipe(recipe uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.actor_active() and exists(select 1 from public.recipes r where r.id=recipe and
    (r.author_id=auth.uid() or (r.visibility='public' and private.is_unblocked(r.author_id))));
$$;
create or replace function private.owns_list(list uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.actor_active() and exists(select 1 from public.shopping_lists l where l.id=list and l.owner_id=auth.uid());
$$;
create or replace function private.can_read_list(list uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.actor_active() and exists(select 1 from public.shopping_lists l where l.id=list and
    (l.owner_id=auth.uid() or (private.is_unblocked(l.owner_id) and exists(
      select 1 from public.shopping_list_members m where m.list_id=list and m.user_id=auth.uid()))));
$$;
-- A stale JWT cannot recreate its own profile through a definer entry point.
-- FK constraints also reject aggregate creation after profile withdrawal.
create function private.block_deleting_storage_owner() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.bucket_id in ('recipe-photos','profile-avatars') and new.owner_id is not null then
    -- Same first lock as account withdrawal. An upload that began earlier must
    -- commit before collection, or observe the committed deletion request.
    perform 1 from auth.users where id=new.owner_id::uuid for key share;
    if not found then raise exception 'Cuenta no disponible' using errcode='42501'; end if;
  end if;
  if exists(select 1 from private.account_deletions d where d.actor_id::text=new.owner_id) then
    raise exception 'Cuenta en eliminación' using errcode='42501'; end if;
  return new;
end;
$$;
create trigger block_deleting_storage_owner before insert or update of owner_id on storage.objects
  for each row execute function private.block_deleting_storage_owner();

create function private.begin_account_deletion(p_actor_id uuid,p_request_id uuid,p_delete_owned_lists boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare job private.account_deletions;
begin
  if p_actor_id is null or p_request_id is null or p_delete_owned_lists is distinct from true then
    raise exception 'Confirmación requerida' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('delete-account:'||p_actor_id::text,0));
  select * into job from private.account_deletions where actor_id=p_actor_id for update;
  if found then return job.id; end if;
  perform 1 from auth.users where id=p_actor_id for update;
  if not found then raise exception 'Cuenta no disponible' using errcode='42501'; end if;
  -- Reference writers take parent -> cleanup-job locks. Follow that order;
  -- do not enqueue/lock jobs and then wait for a profile or recipe writer.
  perform 1 from public.profiles where user_id=p_actor_id for update;
  perform 1 from public.recipes where author_id=p_actor_id order by id for update;
  -- Never remove resources from unknown buckets to make an Auth DELETE pass.
  if exists(select 1 from storage.objects where owner_id=p_actor_id::text and
    (bucket_id not in ('recipe-photos','profile-avatars') or
      not private.cleanup_valid_path(bucket_id,name) or split_part(name,'/',1)<>p_actor_id::text)) then
    raise exception 'Revisión de archivos requerida' using errcode='PT409'; end if;
  insert into private.account_deletions(actor_id,actor_hash,request_id)
    values(p_actor_id,encode(extensions.digest(p_actor_id::text,'sha256'),'hex'),p_request_id) returning * into job;
  insert into private.storage_cleanup_jobs(bucket_id,object_name,owner_id,not_before)
    select bucket_id,name,owner_id,clock_timestamp() from storage.objects where owner_id=p_actor_id::text
    on conflict(bucket_id,object_name) do update set not_before=clock_timestamp();
  -- Remove reports containing personal references to the deleted identity or
  -- its own content, including reports submitted by other accounts.
  delete from public.content_reports cr where (cr.target_type='profile' and cr.target_id=p_actor_id)
    or (cr.target_type='recipe' and cr.target_id in(select id from public.recipes where author_id=p_actor_id))
    or (cr.target_type='comment' and cr.target_id in(select id from public.recipe_comments where author_id=p_actor_id));
  -- Explicit policy: all owned lists/products disappear for collaborators;
  -- foreign lists/products remain, while this identity's memberships disappear.
  delete from public.profiles where user_id=p_actor_id;
  return job.id;
end;
$$;
create function public.begin_account_deletion(p_actor_id uuid,p_request_id uuid,p_delete_owned_lists boolean) returns uuid
language sql security invoker set search_path='' as $$ select private.begin_account_deletion(p_actor_id,p_request_id,p_delete_owned_lists); $$;
-- Recover a lost acceptance response without accepting a foreign identity or
-- requiring a password sign-in after the accepted request already revoked it.
create function private.own_account_deletion(p_request_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('accepted',true,'state',state) from private.account_deletions
    where auth.uid() is not null and request_id=p_request_id and
      actor_hash=encode(extensions.digest(auth.uid()::text,'sha256'),'hex');
$$;
create function public.own_account_deletion(p_request_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$ select private.own_account_deletion(p_request_id); $$;
revoke all on function private.own_account_deletion(uuid),public.own_account_deletion(uuid) from public,anon,authenticated;
grant execute on function private.own_account_deletion(uuid),public.own_account_deletion(uuid) to authenticated;
create function private.claim_account_deletions(p_limit integer default 3) returns setof jsonb
language plpgsql security definer set search_path='' as $$
declare job private.account_deletions; token uuid;
begin
  if p_limit is null or p_limit not between 1 and 5 then raise exception 'Límite no válido' using errcode='22023'; end if;
  for job in select * from private.account_deletions d where d.not_before<=clock_timestamp()
    and (d.state='queued' or (d.state='working' and d.lease_until<clock_timestamp()))
    and not exists(select 1 from storage.objects o where o.owner_id=d.actor_id::text)
    order by d.created_at,d.id for update skip locked limit p_limit loop
    if job.attempts>=5 then
      update private.account_deletions set state='dead',error_code='auth_failure',finished_at=clock_timestamp() where id=job.id;
      continue;
    end if;
    token:=gen_random_uuid();
    update private.account_deletions set state='working',attempts=attempts+1,claim_id=token,
      lease_until=clock_timestamp()+interval '2 minutes',error_code=null where id=job.id;
    return next jsonb_build_object('id',job.id,'actor_id',job.actor_id,'claim_id',token);
  end loop;
end;
$$;
create function public.claim_account_deletions(p_limit integer default 3) returns setof jsonb
language sql security invoker set search_path='' as $$ select private.claim_account_deletions(p_limit); $$;
create function private.finish_account_deletion(p_id uuid,p_claim_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare job private.account_deletions;
begin
  select * into job from private.account_deletions where id=p_id and claim_id=p_claim_id and state='working' for update;
  if not found then return false; end if;
  if not exists(select 1 from auth.users where id=job.actor_id) and
    not exists(select 1 from storage.objects where owner_id=job.actor_id::text) then
    update private.account_deletions set state='done',actor_id=null,claim_id=null,lease_until=null,
      finished_at=clock_timestamp(),error_code=null where id=job.id;
    return true;
  end if;
  update private.account_deletions set state=case when attempts>=5 then 'dead' else 'queued' end,
    not_before=clock_timestamp()+make_interval(secs=>least(3600,30*(2^job.attempts)::integer)),lease_until=null,
    finished_at=case when attempts>=5 then clock_timestamp() end,error_code='auth_failure' where id=job.id;
  return false;
end;
$$;
create function public.finish_account_deletion(p_id uuid,p_claim_id uuid) returns boolean
language sql security invoker set search_path='' as $$ select private.finish_account_deletion(p_id,p_claim_id); $$;
create function private.maintain_private_operations() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  -- Retention is finite for completed traces. Unfinished physical deletion must
  -- stay visible to operations; never lose a pending object to hide a failure.
  delete from private.storage_cleanup_jobs where state='done' and finished_at<clock_timestamp()-interval '30 days'
    and not exists(select 1 from storage.objects o where o.bucket_id=storage_cleanup_jobs.bucket_id and o.name=storage_cleanup_jobs.object_name);
  delete from private.storage_cleanup_jobs where state='dead' and not fenced and finished_at<clock_timestamp()-interval '30 days';
  delete from private.account_deletions where state='done' and finished_at<clock_timestamp()-interval '30 days';
  return jsonb_build_object('storage_pending',(select count(*) from private.storage_cleanup_jobs where state in ('queued','working')),
    'storage_failed',(select count(*) from private.storage_cleanup_jobs where state='dead'),
    'accounts_pending',(select count(*) from private.account_deletions where state in ('queued','working')),
    'accounts_failed',(select count(*) from private.account_deletions where state='dead'));
end;
$$;
create function public.maintain_private_operations() returns jsonb
language sql security invoker set search_path='' as $$ select private.maintain_private_operations(); $$;
revoke all on function private.block_deleting_storage_owner() from public,anon,authenticated;
do $$ declare f record; begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and p.proname in ('begin_account_deletion','claim_account_deletions','finish_account_deletion','maintain_private_operations') loop
    execute format('revoke all on function %s from public,anon,authenticated',f.signature);
    execute format('grant execute on function %s to service_role',f.signature);
  end loop;
end $$;
