create function private.validate_invitation() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.shopping_lists l
    where l.id = new.list_id and l.owner_id = new.sender_id) then
    raise exception 'El remitente debe ser el propietario' using errcode = '23514';
  end if;
  if tg_op = 'INSERT' and new.status <> 'pending' then
    raise exception 'La invitación debe empezar pendiente' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' and (new.id, new.list_id, new.sender_id, new.invitee_id, new.created_at)
    is distinct from (old.id, old.list_id, old.sender_id, old.invitee_id, old.created_at) then
    raise exception 'Los destinatarios de la invitación son inmutables' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger invitation_integrity before insert or update on public.shopping_list_invitations
for each row execute function private.validate_invitation();
create function private.validate_member() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists(select 1 from public.shopping_lists where id = new.list_id and owner_id = new.user_id) then
    raise exception 'El propietario no se duplica como miembro' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger member_integrity before insert or update on public.shopping_list_members
for each row execute function private.validate_member();

-- Minimal anti-abuse limits, enforced in DB even for direct API INSERTs.
-- Trusted migration/fixture SQL with no end-user UID is exempt.
create table private.creation_windows (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  resource text not null,
  window_start timestamptz not null,
  attempts integer not null check (attempts > 0),
  primary key(user_id, resource)
);
alter table private.creation_windows enable row level security;
revoke all on private.creation_windows from public, anon, authenticated;
create function private.limit_content_creation() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_count integer; v_max integer; v_uid uuid := auth.uid();
begin
  if v_uid is null then return new; end if;
  case tg_table_name
    when 'recipes' then
      v_max := 10;
    when 'recipe_comments' then
      v_max := 20;
    when 'shopping_lists' then
      v_max := 20;
    when 'shopping_list_invitations' then
      v_max := 20;
    when 'content_reports' then
      v_max := 5;
  end case;
  insert into private.creation_windows as w(user_id, resource, window_start, attempts)
    values(v_uid, tg_table_name, clock_timestamp(), 1)
    on conflict(user_id, resource) do update set
      attempts = case when w.window_start <= clock_timestamp() - interval '1 minute' then 1 else w.attempts + 1 end,
      window_start = case when w.window_start <= clock_timestamp() - interval '1 minute' then clock_timestamp() else w.window_start end
    returning attempts into v_count;
  -- Counter persists when content is deleted; cannot reset quota by deleting rows.
  if v_count > v_max then
    raise exception 'Demasiadas solicitudes; vuelve a intentarlo más adelante' using errcode = 'PT429';
  end if;
  return new;
end;
$$;
do $$
declare t text;
begin
  foreach t in array array['recipes','recipe_comments','shopping_lists','shopping_list_invitations','content_reports'] loop
    execute format('create trigger creation_limit before insert on public.%I for each row execute function private.limit_content_creation()', t);
  end loop;
end;
$$;
revoke all on function private.validate_invitation(), private.validate_member(), private.limit_content_creation()
  from public, anon, authenticated;
