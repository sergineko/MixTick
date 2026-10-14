-- Phase08 diagnosis: 175k-195k buffer hits and repeated authorization per line.
-- Preserve the matching RPC/algorithm. Evaluate the symmetric block set once
-- per statement and authorize child rows through their RLS-protected parent.
-- This helper is authorization only, never a privileged recipe projection.
create function private.blocked_user_ids() returns uuid[]
language sql stable security definer set search_path='' as $$
  select coalesce(array_agg(distinct other_id),'{}'::uuid[]) from (
    select b.blocked_id other_id from public.user_blocks b where b.blocker_id=(select auth.uid())
    union
    select b.blocker_id from public.user_blocks b where b.blocked_id=(select auth.uid())
  ) blocked;
$$;
revoke all on function private.blocked_user_ids() from public,anon,authenticated;
grant execute on function private.blocked_user_ids() to authenticated;
alter policy recipes_read on public.recipes using (
  (select auth.uid()) is not null and (
    author_id=(select auth.uid()) or (visibility='public' and
      author_id<>all(coalesce((select private.blocked_user_ids()),'{}'::uuid[])))));
alter policy profiles_read on public.profiles using (
  (select auth.uid()) is not null and (user_id=(select auth.uid()) or
    user_id<>all(coalesce((select private.blocked_user_ids()),'{}'::uuid[]))));
alter policy recipe_ingredients_read on public.recipe_ingredients using (
  recipe_id in (select r.id from public.recipes r));
alter policy recipe_steps_read on public.recipe_steps using (
  recipe_id in (select r.id from public.recipes r));
