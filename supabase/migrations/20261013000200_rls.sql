-- Helpers derive their identity from auth.uid(), never from a supplied user ID.
-- Private schema is not exposed by the API. Definer reads break policy cycles.
create function private.is_unblocked(other_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and not exists (
    select 1 from public.user_blocks b where
      (b.blocker_id = auth.uid() and b.blocked_id = other_user) or
      (b.blocked_id = auth.uid() and b.blocker_id = other_user));
$$;
create function private.owns_recipe(recipe uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.recipes r where r.id = recipe and r.author_id = auth.uid());
$$;
create function private.can_read_recipe(recipe uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (select 1 from public.recipes r
    where r.id = recipe and (r.author_id = auth.uid() or
      (r.visibility = 'public' and private.is_unblocked(r.author_id))));
$$;
create function private.can_interact_recipe(recipe uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.recipes r
    where r.id = recipe and r.visibility = 'public' and private.can_read_recipe(r.id));
$$;
create function private.owns_list(list uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.shopping_lists l where l.id = list and l.owner_id = auth.uid());
$$;
create function private.can_read_list(list uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (select 1 from public.shopping_lists l
    where l.id = list and (l.owner_id = auth.uid() or
      (private.is_unblocked(l.owner_id) and exists (
        select 1 from public.shopping_list_members m where m.list_id = list and m.user_id = auth.uid()))));
$$;

do $$
declare t text;
begin
  foreach t in array array['profiles','ingredients','ingredient_aliases','recipes',
    'recipe_ingredients','recipe_steps','recipe_saves','recipe_likes','recipe_comments',
    'user_follows','user_blocks','content_reports','shopping_lists','shopping_list_members',
    'shopping_list_invitations','shopping_items'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('grant all on public.%I to service_role', t);
  end loop;
end;
$$;
alter table private.shopping_imports enable row level security;
alter table private.storage_cleanup_jobs enable row level security;
revoke all on all tables in schema private from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_unblocked(uuid), private.owns_recipe(uuid),
  private.can_read_recipe(uuid), private.can_interact_recipe(uuid),
  private.owns_list(uuid), private.can_read_list(uuid) to authenticated;

create policy profiles_read on public.profiles for select to authenticated
  using (user_id = (select auth.uid()) or private.is_unblocked(user_id));
create policy profiles_insert on public.profiles for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
grant insert(username, display_name, avatar_path), update(username, display_name, avatar_path)
  on public.profiles to authenticated;

create policy ingredients_read on public.ingredients for select to authenticated using (approved);
create policy aliases_read on public.ingredient_aliases for select to authenticated
  using (exists (select 1 from public.ingredients i where i.id = ingredient_id and i.approved));

create policy recipes_read on public.recipes for select to authenticated using (private.can_read_recipe(id));
create policy recipes_delete on public.recipes for delete to authenticated using (private.owns_recipe(id));
grant delete on public.recipes to authenticated;
create policy recipe_ingredients_read on public.recipe_ingredients for select to authenticated
  using (private.can_read_recipe(recipe_id));
create policy recipe_steps_read on public.recipe_steps for select to authenticated
  using (private.can_read_recipe(recipe_id));

create policy saves_read on public.recipe_saves for select to authenticated
  using (user_id = (select auth.uid()) and private.can_read_recipe(recipe_id));
create policy saves_insert on public.recipe_saves for insert to authenticated
  with check (user_id = (select auth.uid()) and private.can_interact_recipe(recipe_id));
create policy saves_delete on public.recipe_saves for delete to authenticated
  using (user_id = (select auth.uid()));
grant insert(recipe_id), delete on public.recipe_saves to authenticated;
create policy likes_read on public.recipe_likes for select to authenticated
  using (private.can_read_recipe(recipe_id) and private.is_unblocked(user_id));
create policy likes_insert on public.recipe_likes for insert to authenticated
  with check (user_id = (select auth.uid()) and private.can_interact_recipe(recipe_id));
create policy likes_delete on public.recipe_likes for delete to authenticated using (user_id = (select auth.uid()));
grant insert(recipe_id), delete on public.recipe_likes to authenticated;
create policy comments_read on public.recipe_comments for select to authenticated
  using (private.can_read_recipe(recipe_id) and private.is_unblocked(author_id));
create policy comments_insert on public.recipe_comments for insert to authenticated
  with check (author_id = (select auth.uid()) and private.can_interact_recipe(recipe_id));
create policy comments_update on public.recipe_comments for update to authenticated
  using (author_id = (select auth.uid()) and private.can_interact_recipe(recipe_id))
  with check (author_id = (select auth.uid()) and private.can_interact_recipe(recipe_id));
create policy comments_delete on public.recipe_comments for delete to authenticated using (author_id = (select auth.uid()));
grant insert(recipe_id, content), update(content), delete on public.recipe_comments to authenticated;

create policy follows_read on public.user_follows for select to authenticated
  using (private.is_unblocked(follower_id) and private.is_unblocked(followed_id));
create policy follows_insert on public.user_follows for insert to authenticated
  with check (follower_id = (select auth.uid()) and private.is_unblocked(followed_id));
create policy follows_delete on public.user_follows for delete to authenticated using (follower_id = (select auth.uid()));
grant insert(followed_id), delete on public.user_follows to authenticated;
create policy blocks_read on public.user_blocks for select to authenticated using (blocker_id = (select auth.uid()));
create policy blocks_insert on public.user_blocks for insert to authenticated with check (blocker_id = (select auth.uid()));
create policy blocks_delete on public.user_blocks for delete to authenticated using (blocker_id = (select auth.uid()));
grant insert(blocked_id), delete on public.user_blocks to authenticated;
create policy reports_read on public.content_reports for select to authenticated using (reporter_id = (select auth.uid()));

create policy lists_read on public.shopping_lists for select to authenticated
  using (owner_id = (select auth.uid()) or private.can_read_list(id));
create policy lists_insert on public.shopping_lists for insert to authenticated with check (owner_id = (select auth.uid()));
create policy lists_update on public.shopping_lists for update to authenticated
  using (private.owns_list(id)) with check (private.owns_list(id));
create policy lists_delete on public.shopping_lists for delete to authenticated using (private.owns_list(id));
grant insert(title), update(title), delete on public.shopping_lists to authenticated;
create policy members_read on public.shopping_list_members for select to authenticated using (private.can_read_list(list_id));
create policy invitations_read on public.shopping_list_invitations for select to authenticated
  using ((private.owns_list(list_id) or invitee_id = (select auth.uid())) and private.is_unblocked(sender_id)
    and private.is_unblocked(invitee_id));
create policy shopping_items_read on public.shopping_items for select to authenticated using (private.can_read_list(list_id));

-- Clients cannot write recipe aggregates, members/invitations or items directly.
-- RPCs in the next migration enforce transactional validation and row versions.
create function public.resolve_ingredient(p_name text) returns uuid
language sql stable security invoker set search_path = '' as $$
  select a.ingredient_id from public.ingredient_aliases a
    join public.ingredients i on i.id = a.ingredient_id
    where a.normalized_alias = private.normalize_text(p_name) and i.approved;
$$;
revoke all on function public.resolve_ingredient(text) from public, anon;
grant execute on function public.resolve_ingredient(text), private.normalize_text(text) to authenticated;
