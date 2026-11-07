-- db/138_warforged_race.sql
--
-- Adds Warforged (Eberron: Rising from the Last War) to the shared race
-- catalogue, so it appears in every campaign's race picker. 055 seeded only
-- the nine races of the 2014 Player's Handbook; this is a deliberate addition
-- from outside that book, not a correction to 055.
--
-- A SHARED ROW, NOT HOMEBREW. campaign_id is omitted, so it defaults to null
-- and reaches every campaign. 054's INSERT policy forbids a client from
-- writing a shared row; this file can because a migration runs as the table
-- owner, outside RLS (055's reasoning). Homebrew would have meant one insert
-- per campaign, and nothing in the app creates races yet.
--
-- ONLY SPEED AND SIZE ARE COMPUTED WITH. Everything else Warforged gets is
-- description text, as 055 does for every race:
--   Integrated Protection (+1 AC) is NOT added automatically. armorClass() in
--     src/data/rules.ts takes no racial input; enter it as the sheet's "other"
--     AC bonus. A racial AC modifier would be a column, i.e. a schema change.
--   Constructed Resilience (poison resistance, no eating/breathing/sleeping)
--     and Sentry's Rest are text only, like the Dwarf's poison resilience.
--   The +2 CON / +1 other ASI is not stored: the sheet takes final scores (055).
--
-- races has no unique name, so the insert is guarded with `not exists` and the
-- assertion checks the end state: exactly one shared Warforged with the right
-- numbers, whatever was there before.
--
-- No schema change, so no `npm run gen:types` and no schema reload.
--
-- RUN AS ONE BLOCK. CORRECT OUTPUT: "Success. No rows returned."

begin;

insert into public.races (name, speed, size, description)
select $$Warforged$$, 30, 'medium',
       $$Living constructs built for war, with armour worked into their bodies, resistance to poison, and no need to eat, breathe or sleep.$$
 where not exists (
   select 1 from public.races r
    where r.campaign_id is null and r.name = 'Warforged'
 );

do $do$
declare
  v_found int;
begin
  select count(*) into v_found
    from public.races r
   where r.campaign_id is null
     and r.name = 'Warforged'
     and r.speed = 30
     and r.size = 'medium';
  if v_found <> 1 then
    raise exception 'expected one shared Warforged (30 ft, medium), found %', v_found;
  end if;
end
$do$;

insert into public.schema_migrations (version) values ('138');

commit;
