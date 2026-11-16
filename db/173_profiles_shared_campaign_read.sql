-- db/173_profiles_shared_campaign_read.sql
--
-- A profile is readable by the people who share a campaign with it, not by
-- every signed-in account on the internet.
--
-- WHAT WAS WRONG. 007 opened profiles with "authenticated read profiles",
-- `using (true)`, so recap bylines would show a name. 007 predates campaigns:
-- one group used the app then, and "any signed-in user" meant "my players".
-- 010-020 scoped every other read to campaign membership, and 018's tenancy
-- rule ("a member of campaign A receives nothing of B") was never applied
-- here. Sign-in is open to any Google account, and the demo seat
-- (#/demo) hands out a session to anyone at all. Either one could read every
-- profile in every campaign: display name, user id, and the global role flag
-- that shows which accounts are DMs. (audit/pass-1-security.md, H1.)
--
-- WHO LEGITIMATELY READS SOMEONE ELSE'S PROFILE. Every reader in src/ is one
-- of these:
--   party roster names        members of this campaign  (characters.ts)
--   inventory "from" byline   the owner or the DM       (characterInventory.ts)
--   recap last_edited_by      a member                  (recaps.ts)
--   player-invite claimant    a member once claimed     (invites.ts)
--   DM-invite claimant        another global DM         (invites.ts)
-- The first four all share a campaign with the reader. The fifth usually
-- doesn't: a DM invite carries no campaign, and the new DM has made none yet.
-- So the new policy has two branches, each behind its own function.
--
-- Your own row is still covered by the existing "select own profile"
-- (`auth.uid() = id`), which is untouched. AuthContext, is_dm() and
-- dm_invites' own policy all read only that row.
--
-- WHY BOTH FUNCTIONS ARE SECURITY DEFINER. This is not a recursion break
-- (018's reason for is_campaign_dm). Each one is a gated read past RLS:
--   shares_campaign_with   campaign_members' SELECT is `user_id = auth.uid()`.
--                          An invoker join would only ever see the caller's
--                          own rows, so it would refuse everyone else.
--   dm_invite_claimant_visible  dm_invites' SELECT policy ("dms can view
--                          invites", 000) reads profiles. Reading
--                          dm_invites as invoker from a profiles policy
--                          would recurse (42P17).
-- The gate is in the body and is always about auth.uid(). Neither takes an
-- argument that names the caller, and each returns one boolean that the
-- caller could already work out ("do I share a campaign with X", "did X claim
-- a DM invite I can already see"). Definer means the EXECUTE grant is the only
-- gate, hence the revoke from public and anon (008's rule). authenticated
-- keeps EXECUTE because a policy calls a function with the querying role's
-- privileges.
--
-- FORMER MEMBERS. Someone who leaves (or is removed from) a campaign stops
-- sharing it, so their name on old bylines and claimed invites reads null.
-- Every mapper already handles a null embed (`?.display_name ?? null`).
--
-- Run by Claude via `npx supabase db query --linked`. In the SQL editor,
-- decline "Run and enable RLS" (CLAUDE.md): this file creates no table.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."
-- Not idempotent on purpose: the ledger insert refuses a second run.

begin;

create or replace function public.shares_campaign_with(target uuid)
 returns boolean
 language sql
 security definer
 set search_path to 'public'
 stable
as $function$
  select exists (
    select 1
      from campaign_members me
      join campaign_members them on them.campaign_id = me.campaign_id
     where me.user_id = auth.uid()
       and them.user_id = target
  );
$function$
;

-- is_dm() is invoker and reads only the caller's own profiles row. Inside a
-- definer body it runs as the owner, so profiles' RLS isn't consulted and
-- nothing recurses.
create or replace function public.dm_invite_claimant_visible(target uuid)
 returns boolean
 language sql
 security definer
 set search_path to 'public'
 stable
as $function$
  select public.is_dm()
     and exists (select 1 from dm_invites where used_by = target);
$function$
;

revoke execute on function public.shares_campaign_with(uuid) from public, anon;
grant  execute on function public.shares_campaign_with(uuid) to authenticated;
revoke execute on function public.dm_invite_claimant_visible(uuid) from public, anon;
grant  execute on function public.dm_invite_claimant_visible(uuid) to authenticated;

drop policy "authenticated read profiles" on public.profiles;

create policy "read profiles of campaign peers" on public.profiles
  for select to authenticated
  using (
    public.shares_campaign_with(id)
    or public.dm_invite_claimant_visible(id)
  );

-- Assert the end state.
do $$
declare
  f text;
begin
  if exists (select 1 from pg_policies
              where schemaname = 'public' and tablename = 'profiles'
                and cmd = 'SELECT' and qual = 'true') then
    raise exception 'profiles still has a using (true) SELECT policy. Rolled back.';
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'profiles'
                    and policyname = 'read profiles of campaign peers') then
    raise exception 'New profiles policy missing. Rolled back.';
  end if;

  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'profiles'
                    and policyname = 'select own profile') then
    raise exception '"select own profile" is gone; own-row reads would break. Rolled back.';
  end if;

  foreach f in array array['public.shares_campaign_with(uuid)',
                           'public.dm_invite_claimant_visible(uuid)'] loop
    if not exists (select 1 from pg_proc
                    where oid = f::regprocedure
                      and prosecdef
                      and proconfig @> array['search_path=public']) then
      raise exception '% is not definer with a pinned search_path. Rolled back.', f;
    end if;
    if has_function_privilege('anon', f, 'execute') then
      raise exception 'anon can execute %. Rolled back.', f;
    end if;
    if not has_function_privilege('authenticated', f, 'execute') then
      raise exception 'authenticated cannot execute %. Rolled back.', f;
    end if;
  end loop;
end $$;

insert into public.schema_migrations (version) values ('173');

commit;


-- ===========================================================================
-- VERIFICATION (run each block on its own; each ends in rollback)
-- ===========================================================================
--
-- Each block works out the expected count as the owner first, stores it in a
-- transaction-local setting, then switches to the authenticated role and
-- compares. CORRECT OUTPUT for every block: one row, every boolean column `t`.

-- BLOCK 1: a signed-in stranger with no memberships sees no profile at all.
begin;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000abcd","role":"authenticated"}', true);
set local role authenticated;
select (select count(*) from profiles) = 0 as stranger_sees_nothing;
rollback;

-- BLOCK 2: the demo account sees exactly its campaign peers (itself included).
begin;
select set_config('audit.expected', (
  select count(distinct them.user_id)::text
    from campaign_members me
    join campaign_members them on them.campaign_id = me.campaign_id
   where me.user_id = 'db449b7c-b8d7-47e0-976c-a0ec23ef283f'), true);
select set_config('request.jwt.claims',
  '{"sub":"db449b7c-b8d7-47e0-976c-a0ec23ef283f","role":"authenticated"}', true);
set local role authenticated;
select count(*) as visible,
       current_setting('audit.expected')::int as expected,
       count(*) = current_setting('audit.expected')::int as demo_sees_peers_only,
       bool_or(id = auth.uid()) as demo_sees_self,
       count(*) filter (where role = 'dm') as dms_visible
  from profiles;
rollback;

-- BLOCK 3: a global DM (the first by id) sees their campaign peers plus every
-- DM-invite claimant, and the join through dm_invites doesn't recurse (a
-- 42P17 would abort the block).
begin;
select set_config('audit.dm', (select min(id::text) from profiles where role = 'dm'), true);
select set_config('audit.expected', (
  select count(*)::text from profiles p
   where p.id = current_setting('audit.dm')::uuid
      or exists (select 1 from campaign_members me
                   join campaign_members them on them.campaign_id = me.campaign_id
                  where me.user_id = current_setting('audit.dm')::uuid
                    and them.user_id = p.id)
      or exists (select 1 from dm_invites i where i.used_by = p.id)), true);
select set_config('audit.claimants',
  (select count(distinct used_by)::text from dm_invites where used_by is not null), true);
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('audit.dm'), 'role', 'authenticated')::text, true);
set local role authenticated;
select (select count(*) from profiles) as visible,
       current_setting('audit.expected')::int as expected,
       (select count(*) from profiles) = current_setting('audit.expected')::int as dm_sees_expected,
       (select count(distinct p.id) from dm_invites i join profiles p on p.id = i.used_by)
         = current_setting('audit.claimants')::int as claimants_visible;
rollback;
