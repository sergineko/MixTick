-- MixTick Phase 02. Run only through versioned migrations, never from mobile.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create extension if not exists unaccent with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create function private.normalize_text(value text) returns text
language sql immutable strict set search_path = '' as $$
  select pg_catalog.regexp_replace(
    pg_catalog.lower(extensions.unaccent('extensions.unaccent', pg_catalog.btrim(value))),
    '\s+', ' ', 'g');
$$;

create function private.touch_row() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := pg_catalog.clock_timestamp();
  new.version := old.version + 1;
  return new;
end;
$$;

create table public.profiles (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,30}$'),
  display_name text not null check (char_length(btrim(display_name)) between 1 and 60),
  avatar_path text check (avatar_path is null or avatar_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0)
);
create function private.normalize_username() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.username := pg_catalog.lower(pg_catalog.btrim(new.username));
  return new;
end;
$$;
create trigger profile_username before insert or update of username on public.profiles
for each row execute function private.normalize_username();

create table public.ingredients (
  id uuid primary key default gen_random_uuid(),
  canonical_name_es text not null check (char_length(btrim(canonical_name_es)) between 1 and 80),
  normalized_key text generated always as (private.normalize_text(canonical_name_es)) stored unique,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.ingredient_aliases (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.ingredients(id) on delete cascade,
  alias_es text not null check (char_length(btrim(alias_es)) between 1 and 80),
  normalized_alias text generated always as (private.normalize_text(alias_es)) stored unique
);
create index ingredient_alias_prefix on public.ingredient_aliases (normalized_alias text_pattern_ops);
create index ingredient_alias_parent on public.ingredient_aliases (ingredient_id);
create function private.register_canonical_alias() returns trigger
language plpgsql set search_path = '' as $$
begin
  insert into public.ingredient_aliases(ingredient_id, alias_es)
  values (new.id, new.canonical_name_es) on conflict (normalized_alias) do nothing;
  if exists (select 1 from public.ingredient_aliases a
    where a.normalized_alias = private.normalize_text(new.canonical_name_es)
      and a.ingredient_id <> new.id) then
    raise exception 'El nombre canónico ya identifica otro ingrediente' using errcode = '23505';
  end if;
  return new;
end;
$$;
create function private.validate_alias() returns trigger
language plpgsql set search_path = '' as $$
begin
  if exists (select 1 from public.ingredients i
    where i.normalized_key = private.normalize_text(new.alias_es)
      and i.id <> new.ingredient_id) then
    raise exception 'El alias identifica otro ingrediente' using errcode = '23505';
  end if;
  return new;
end;
$$;
create trigger ingredient_canonical_alias after insert or update of canonical_name_es
on public.ingredients for each row execute function private.register_canonical_alias();
create trigger alias_integrity before insert or update on public.ingredient_aliases
for each row execute function private.validate_alias();

create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(user_id) on delete cascade,
  visibility text not null default 'private' check (visibility in ('private', 'public')),
  title text not null check (char_length(btrim(title)) between 1 and 120),
  description text check (description is null or char_length(description) <= 4000),
  category text not null check (char_length(btrim(category)) between 1 and 60),
  servings numeric(8,2) not null check (servings > 0 and servings <= 10000),
  prep_minutes integer check (prep_minutes between 0 and 10080),
  cook_minutes integer check (cook_minutes between 0 and 10080),
  hero_image_path text,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  check (hero_image_path is null or
    (hero_image_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
      and split_part(hero_image_path, '/', 1) = author_id::text
      and split_part(hero_image_path, '/', 2) = id::text)),
  check (visibility = 'private' or published_at is not null)
);
create index recipes_author on public.recipes(author_id, created_at desc, id);
create index recipes_public_feed on public.recipes(published_at desc, id) where visibility = 'public';
create index recipes_title_search on public.recipes using gin(to_tsvector('spanish', title));

create table public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  ingredient_id uuid references public.ingredients(id) on delete restrict,
  custom_name text check (custom_name is null or char_length(btrim(custom_name)) between 1 and 80),
  custom_key text generated always as (private.normalize_text(custom_name)) stored,
  quantity numeric(12,3) check (quantity > 0 and quantity <= 1000000),
  unit text check (unit is null or char_length(btrim(unit)) between 1 and 30),
  optional boolean not null default false,
  sort_order integer not null check (sort_order between 0 and 99),
  unique(recipe_id, sort_order),
  check ((ingredient_id is not null) <> (custom_name is not null))
);
create index recipe_ingredients_catalog on public.recipe_ingredients(ingredient_id, recipe_id);
create table public.recipe_steps (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  sort_order integer not null check (sort_order between 0 and 99),
  instruction text not null check (char_length(btrim(instruction)) between 1 and 4000),
  unique(recipe_id, sort_order)
);
create table public.recipe_saves (
  user_id uuid not null default auth.uid() references public.profiles(user_id) on delete cascade,
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, recipe_id)
);
create index recipe_saves_parent on public.recipe_saves(recipe_id);
create table public.recipe_likes (
  user_id uuid not null default auth.uid() references public.profiles(user_id) on delete cascade,
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, recipe_id)
);
create index recipe_likes_parent on public.recipe_likes(recipe_id);
create table public.recipe_comments (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  author_id uuid not null default auth.uid() references public.profiles(user_id) on delete cascade,
  content text not null check (char_length(btrim(content)) between 1 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0)
);
create index recipe_comments_parent on public.recipe_comments(recipe_id, created_at, id);
create index recipe_comments_author on public.recipe_comments(author_id);
create table public.user_follows (
  follower_id uuid not null default auth.uid() references public.profiles(user_id) on delete cascade,
  followed_id uuid not null references public.profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(follower_id, followed_id),
  check (follower_id <> followed_id)
);
create index follows_target on public.user_follows(followed_id);
create table public.user_blocks (
  blocker_id uuid not null default auth.uid() references public.profiles(user_id) on delete cascade,
  blocked_id uuid not null references public.profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index blocks_target on public.user_blocks(blocked_id, blocker_id);
create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(user_id) on delete cascade,
  target_type text not null check (target_type in ('recipe', 'comment', 'profile')),
  target_id uuid not null,
  reason text not null check (char_length(btrim(reason)) between 10 and 1000),
  status text not null default 'open' check (status in ('open', 'reviewed', 'closed')),
  created_at timestamptz not null default now()
);
create index reports_owner on public.content_reports(reporter_id, created_at desc);
create index reports_target on public.content_reports(target_type, target_id);

create table public.shopping_lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles(user_id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0)
);
create index shopping_lists_owner on public.shopping_lists(owner_id);
create table public.shopping_list_members (
  list_id uuid not null references public.shopping_lists(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(list_id, user_id)
);
create index shopping_members_user on public.shopping_list_members(user_id, list_id);
create table public.shopping_list_invitations (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.shopping_lists(id) on delete cascade,
  sender_id uuid not null references public.profiles(user_id) on delete cascade,
  invitee_id uuid not null references public.profiles(user_id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'revoked')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (sender_id <> invitee_id),
  check ((status = 'pending') = (responded_at is null))
);
create unique index invitation_pending_unique on public.shopping_list_invitations(list_id, invitee_id) where status = 'pending';
create index invitation_recipient on public.shopping_list_invitations(invitee_id, status);
create index invitation_list on public.shopping_list_invitations(list_id);
create table public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.shopping_lists(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  ingredient_id uuid references public.ingredients(id) on delete restrict,
  quantity numeric(12,3) check (quantity > 0 and quantity <= 1000000),
  unit text check (unit is null or char_length(btrim(unit)) between 1 and 30),
  is_purchased boolean not null default false,
  source_key text check (source_key is null or char_length(source_key) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0)
);
create unique index shopping_source_unique on public.shopping_items(list_id, source_key) where source_key is not null;
create index shopping_items_list on public.shopping_items(list_id, is_purchased, created_at, id);
create index shopping_items_catalog on public.shopping_items(ingredient_id);

-- Technical data never exposed through PostgREST or Realtime.
create table private.shopping_imports (
  actor_id uuid not null references public.profiles(user_id) on delete cascade,
  request_id uuid not null,
  list_id uuid not null references public.shopping_lists(id) on delete cascade,
  payload_hash text not null,
  item_ids uuid[] not null,
  created_at timestamptz not null default now(),
  primary key(actor_id, request_id)
);
create index import_list on private.shopping_imports(list_id);
create table private.storage_cleanup_jobs (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  object_name text not null,
  created_at timestamptz not null default now(),
  unique(bucket_id, object_name)
);

do $$
declare t text;
begin
  foreach t in array array['profiles','recipes','recipe_comments','shopping_lists','shopping_items'] loop
    execute format('create trigger server_timestamp before update on public.%I for each row execute function private.touch_row()', t);
  end loop;
end;
$$;

create function private.touch_list() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.shopping_lists set updated_at = pg_catalog.clock_timestamp()
    where id = coalesce(new.list_id, old.list_id);
  return coalesce(new, old);
end;
$$;
create trigger item_list_revision after insert or update or delete on public.shopping_items
for each row execute function private.touch_list();
create trigger member_list_revision after insert or delete on public.shopping_list_members
for each row execute function private.touch_list();

create function private.queue_recipe_photos() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into private.storage_cleanup_jobs(bucket_id, object_name)
  select o.bucket_id, o.name from storage.objects o
    where o.bucket_id = 'recipe-photos'
      and o.name like old.author_id::text || '/' || old.id::text || '/%'
  on conflict do nothing;
  return old;
end;
$$;
create trigger deleted_recipe_photos after delete on public.recipes
for each row execute function private.queue_recipe_photos();
