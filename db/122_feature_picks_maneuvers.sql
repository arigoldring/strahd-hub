-- db/122_feature_picks_maneuvers.sql
--
-- Features that grant many picks from one list, starting with the Battle
-- Master's maneuvers. 095 allowed one pick per feature per class entry; that
-- covered every Fighting Style row and nothing else (KNOWN_ISSUES, "Features
-- with many picks"). This file adds the machinery the old feat/feature-choices
-- branch designed, and the first list to use it.
--
-- RUN AFTER the client that saves picks by insert/update/delete is live
-- (commit "save feature picks by insert, update and delete, not upsert").
-- The client before that one upserted on the unique this file drops, and
-- such an upsert fails once the unique is gone (42P10). The database can't
-- see which client is deployed, so this guard is a sentence.
--
-- FOUR CHANGES:
--
--   1. class_feature_picks (feature_id, level, total): from class level
--      `level` on, the feature allows `total` picks. A step function:
--      Combat Superiority is (3,3) (7,5) (10,7) (15,9). NO ROWS MEANS ONE
--      PICK, so every feature 095 seeded keeps working unchanged. The old
--      branch's shape and policies: read through the feature's own SELECT,
--      and a DM may write rows only for their own campaign's homebrew.
--
--   2. character_feature_choices loses unique (character_class_id,
--      feature_id), and a BEFORE INSERT trigger enforces the allowance
--      instead. It locks the class entry row first (SELECT ... FOR UPDATE),
--      so two tabs adding a maneuver at once queue rather than both passing
--      the count, the race 032's decrement lock exists for. The trigger is
--      security invoker: the lock needs UPDATE rights on the class entry,
--      which are exactly the rights (can_edit_character) needed to add the
--      pick at all. A refused pick raises 23514.
--      * Only INSERT is checked. Changing a pick's option is an UPDATE that
--        doesn't change the count, and a level drop keeps every pick (095's
--        rule): the sheet hides features above the class's level and shows
--        "4 of 3" for a list above its allowance, and adding stays closed.
--      * unique (character_id, option_id) stays: a maneuver, like a style,
--        is learned once.
--      * feature_picks_allowed(feature, class_level) is the rule in one
--        function. picksAllowed in src/data/rules.ts is the same rule for
--        the sheet. ONE RULE IN TWO PLACES; change them together.
--
--   3. feature_options gains `prerequisite text`, display only, like
--      feats.prerequisite: Hill and Storm runes ("7th level") and most
--      invocations need it. Nothing reads it but the picker's label.
--
--   4. Maneuvers: kind 'maneuver' joins the CHECK (one list in two places
--      with FEATURE_OPTION_KINDS), 23 shared options are seeded (16 PHB, 7
--      Tasha's "Maneuver Options", labelled Tasha's by the picker the way
--      its fighting styles are), and Combat Superiority links all 23 with
--      the four allowance rows. Its text drops the maneuver list, now that
--      each maneuver carries its own. The PHB texts are 082's, already in
--      our own words; the Tasha's ones are new, same style.
--
-- Not linked: Superior Technique (a Tasha's fighting style) and the Martial
-- Adept feat also teach a maneuver. Neither is a class_features row, so
-- neither can carry a link; the player notes those by hand.
--
-- THE SQL EDITOR WILL OFFER "Run and enable RLS". This file enables RLS on its
-- own table; take the option that runs WITHOUT enabling (CLAUDE.md).
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- ---------- 1. class_feature_picks ----------

create table public.class_feature_picks (
  feature_id uuid not null references public.class_features(id) on delete cascade,
  level smallint not null check (level between 1 and 20),
  total smallint not null check (total between 1 and 30),
  primary key (feature_id, level)
);

alter table public.class_feature_picks enable row level security;

create policy "read picks of visible features"
  on public.class_feature_picks for select to authenticated
  using (exists (select 1 from public.class_features f
                  where f.id = class_feature_picks.feature_id));

create policy "dms set picks on homebrew features"
  on public.class_feature_picks for insert to authenticated
  with check (
    exists (
      select 1 from public.class_features f
       where f.id = class_feature_picks.feature_id
         and f.campaign_id is not null
         and public.is_campaign_dm(f.campaign_id)
    )
  );

-- The rule, once. No rows: one pick. Rows: the total of the highest row at
-- or below the class level, or none before the first row.
create or replace function public.feature_picks_allowed(target_feature uuid, class_level int)
 returns int
 language sql
 stable
 security invoker
 set search_path to 'public'
as $function$
  select case
    when not exists (select 1 from class_feature_picks where feature_id = target_feature)
      then 1
    else coalesce((select total from class_feature_picks
                    where feature_id = target_feature and level <= class_level
                    order by level desc limit 1), 0)
  end;
$function$
;

-- ---------- 2. the allowance replaces the one-pick unique ----------

alter table public.character_feature_choices
  drop constraint character_feature_choices_character_class_id_feature_id_key;

create or replace function public.limit_feature_picks()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
declare
  v_level   int;
  v_allowed int;
  v_count   int;
begin
  -- Serialise adds to one class entry. A row RLS hides is left to the
  -- INSERT policy and the FK, which refuse it anyway.
  select level into v_level
    from character_classes
   where id = new.character_class_id
     for update;
  if not found then
    return new;
  end if;

  v_allowed := feature_picks_allowed(new.feature_id, v_level);
  select count(*) into v_count
    from character_feature_choices
   where character_class_id = new.character_class_id
     and feature_id = new.feature_id;

  if v_count >= v_allowed then
    raise exception 'This feature allows % pick(s) at class level %, and % are taken.',
      v_allowed, v_level, v_count
      using errcode = 'check_violation';
  end if;
  return new;
end;
$function$
;

create trigger limit_feature_picks
  before insert on public.character_feature_choices
  for each row execute function public.limit_feature_picks();

-- ---------- 3. prerequisite ----------

alter table public.feature_options
  add column prerequisite text check (prerequisite is null or length(btrim(prerequisite)) between 1 and 200);

-- ---------- 4. maneuvers ----------

-- 095's CHECK was inline, so Postgres named it feature_options_kind_check.
-- Dropping a name that isn't there raises and rolls the file back: wanted.
alter table public.feature_options drop constraint feature_options_kind_check;
alter table public.feature_options
  add constraint feature_options_kind_check check (kind in ('fighting_style', 'maneuver'));

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class        constant text := 'Fighter';
  c_subclass     constant text := 'Battle Master';
  c_feature      constant text := 'Combat Superiority';
  c_expected_phb constant int  := 16;
  c_expected_tc  constant int  := 7;

  v_seeking  text;
  v_class    uuid;
  v_subclass uuid;
  v_feature  uuid;
  v_count    int;
  v_updated  int;
begin
  v_seeking := format('shared class "%s"', c_class);
  select id into strict v_class
    from public.classes where name = c_class and campaign_id is null;

  v_seeking := format('%s subclass "%s"', c_class, c_subclass);
  select id into strict v_subclass
    from public.subclasses
   where class_id = v_class and name = c_subclass and campaign_id is null;

  v_seeking := format('%s feature "%s"', c_subclass, c_feature);
  select id into strict v_feature
    from public.class_features
   where class_id = v_class and subclass_id = v_subclass and name = c_feature
     and campaign_id is null;

  -- "The die" is the superiority die spent.
  insert into public.feature_options (kind, key, name, source, description)
  values
    ('maneuver', 'commanders_strike', 'Commander''s Strike', 'phb',
     'Give up one of your attacks and spend a bonus action; an ally who can see '
     'or hear you uses their reaction to make one weapon attack, adding the die '
     'to its damage.'),
    ('maneuver', 'disarming_attack', 'Disarming Attack', 'phb',
     'On a hit, add the die to damage; the target makes a Strength save or '
     'drops one held item of your choice at its feet.'),
    ('maneuver', 'distracting_strike', 'Distracting Strike', 'phb',
     'On a hit, add the die to damage; the next attack against the target by '
     'someone other than you, before the start of your next turn, has '
     'advantage.'),
    ('maneuver', 'evasive_footwork', 'Evasive Footwork', 'phb',
     'When you move, add the die to your AC until you stop moving.'),
    ('maneuver', 'feinting_attack', 'Feinting Attack', 'phb',
     'Spend a bonus action on a creature within 5 feet; you have advantage on '
     'your next attack against it this turn, and add the die to that attack''s '
     'damage if it hits.'),
    ('maneuver', 'goading_attack', 'Goading Attack', 'phb',
     'On a hit, add the die to damage; the target makes a Wisdom save or has '
     'disadvantage on attacks against anyone but you until the end of your '
     'next turn.'),
    ('maneuver', 'lunging_attack', 'Lunging Attack', 'phb',
     'One melee weapon attack on your turn gets 5 extra feet of reach; on a '
     'hit, add the die to damage.'),
    ('maneuver', 'maneuvering_attack', 'Maneuvering Attack', 'phb',
     'On a hit, add the die to damage; an ally who can see or hear you may use '
     'their reaction to move up to half their speed without provoking '
     'opportunity attacks from the target.'),
    ('maneuver', 'menacing_attack', 'Menacing Attack', 'phb',
     'On a hit, add the die to damage; the target makes a Wisdom save or is '
     'frightened of you until the end of your next turn.'),
    ('maneuver', 'parry', 'Parry', 'phb',
     'When a creature damages you with a melee attack, use your reaction to '
     'reduce the damage by the die + your Dexterity modifier.'),
    ('maneuver', 'precision_attack', 'Precision Attack', 'phb',
     'Add the die to a weapon attack roll, before or after rolling but before '
     'you know whether it hits.'),
    ('maneuver', 'pushing_attack', 'Pushing Attack', 'phb',
     'On a hit, add the die to damage; a Large or smaller target makes a '
     'Strength save or is pushed up to 15 feet away.'),
    ('maneuver', 'rally', 'Rally', 'phb',
     'Spend a bonus action; an ally who can see or hear you gains temporary hit '
     'points equal to the die + your Charisma modifier.'),
    ('maneuver', 'riposte', 'Riposte', 'phb',
     'When a creature misses you with a melee attack, use your reaction to make '
     'a melee weapon attack against it; on a hit, add the die to damage.'),
    ('maneuver', 'sweeping_attack', 'Sweeping Attack', 'phb',
     'When you hit with a melee weapon attack, pick another creature within 5 '
     'feet of the target and within your reach; if the original roll would hit '
     'it, it takes damage equal to the die, of the same type.'),
    ('maneuver', 'trip_attack', 'Trip Attack', 'phb',
     'On a hit, add the die to damage; a Large or smaller target makes a '
     'Strength save or is knocked prone.'),
    ('maneuver', 'ambush', 'Ambush', 'tcoe',
     'Add the die to a Dexterity (Stealth) check or an initiative roll, unless '
     'you are incapacitated.'),
    ('maneuver', 'bait_and_switch', 'Bait and Switch', 'tcoe',
     'On your turn, spend 5 feet of movement to swap places with a willing '
     'creature within 5 feet, without provoking opportunity attacks. You or it '
     'adds the die to AC until the start of your next turn.'),
    ('maneuver', 'brace', 'Brace', 'tcoe',
     'When a creature you can see moves into the reach of your melee weapon, '
     'use your reaction to attack it once; on a hit, add the die to damage.'),
    ('maneuver', 'commanding_presence', 'Commanding Presence', 'tcoe',
     'Add the die to a Charisma (Intimidation, Performance or Persuasion) '
     'check.'),
    ('maneuver', 'grappling_strike', 'Grappling Strike', 'tcoe',
     'Right after you hit with a melee attack on your turn, try to grapple the '
     'target as a bonus action, adding the die to your Strength (Athletics) '
     'check.'),
    ('maneuver', 'quick_toss', 'Quick Toss', 'tcoe',
     'Bonus action: make a ranged attack with a thrown weapon, drawing it as '
     'part of the attack; on a hit, add the die to damage.'),
    ('maneuver', 'tactical_assessment', 'Tactical Assessment', 'tcoe',
     'Add the die to an Intelligence (Investigation or History) or Wisdom '
     '(Insight) check.');

  insert into public.class_feature_options (feature_id, option_id)
  select v_feature, o.id
    from public.feature_options o
   where o.kind = 'maneuver' and o.campaign_id is null;

  insert into public.class_feature_picks (feature_id, level, total)
  values (v_feature, 3, 3), (v_feature, 7, 5), (v_feature, 10, 7), (v_feature, 15, 9);

  update public.class_features
     set description = concat_ws(E'\n',
       'You learn three maneuvers (pick them below), two more at 7th, 10th and '
       '15th level, and each time you learn new ones you may swap one you know '
       'for another. You can use only one maneuver per attack.',
       '',
       'Superiority dice: you have four d8s, a fifth at 7th level and a sixth at '
       '15th. A maneuver spends one. You regain all spent dice when you finish a '
       'short or long rest.',
       '',
       'Saving throws: DC = 8 + your proficiency bonus + your Strength or '
       'Dexterity modifier (your choice).')
   where id = v_feature;
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'Rewrote % Combat Superiority rows (expected 1). Rolled back.', v_updated;
  end if;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
    from public.feature_options
   where kind = 'maneuver' and campaign_id is null and source = 'phb';
  if v_count <> c_expected_phb then
    raise exception '% PHB maneuvers (expected %). Rolled back.', v_count, c_expected_phb;
  end if;

  select count(*) into v_count
    from public.feature_options
   where kind = 'maneuver' and campaign_id is null and source = 'tcoe';
  if v_count <> c_expected_tc then
    raise exception '% Tasha''s maneuvers (expected %). Rolled back.', v_count, c_expected_tc;
  end if;

  select count(*) into v_count
    from public.class_feature_options where feature_id = v_feature;
  if v_count <> c_expected_phb + c_expected_tc then
    raise exception '% links on Combat Superiority (expected %). Rolled back.',
      v_count, c_expected_phb + c_expected_tc;
  end if;

  if public.feature_picks_allowed(v_feature, 2) <> 0
     or public.feature_picks_allowed(v_feature, 3) <> 3
     or public.feature_picks_allowed(v_feature, 9) <> 5
     or public.feature_picks_allowed(v_feature, 20) <> 9 then
    raise exception 'Combat Superiority''s allowance is wrong. Rolled back.';
  end if;
exception
  when no_data_found then
    raise exception 'Found no %. 055/071/082 seed it. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one %. Resolve the duplicate first. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('122');

commit;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================
--
-- Run one block at a time. Every block ends in rollback.
--
--   campaign A   d721b412-2750-492e-bddd-7387fc464bba   The cool kids
--   player of A  1313672b-6990-45a6-8a28-c448ca116d2d   Nat
--   DM of A      ea74d56b-8f45-4e4c-80f8-90a6d29b5adf   Dlizard72


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 2 from pg_policies
    where schemaname = 'public' and tablename = 'class_feature_picks')     as picks_policies,
  (select relrowsecurity from pg_class
    where oid = 'public.class_feature_picks'::regclass)                     as rls_on,
  (select count(*) = 0 from pg_constraint
    where conname = 'character_feature_choices_character_class_id_feature_id_key') as one_pick_unique_gone,
  (select count(*) = 1 from pg_constraint
    where conname = 'character_feature_choices_character_id_option_id_key') as option_once_kept,
  (select count(*) = 1 from pg_trigger
    where tgrelid = 'public.character_feature_choices'::regclass
      and tgname = 'limit_feature_picks')                                    as limit_trigger,
  (select bool_and(not prosecdef) from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('limit_feature_picks', 'feature_picks_allowed'))       as all_invoker,
  (select count(*) = 23 from public.feature_options where kind = 'maneuver') as twenty_three,
  (select count(*) = 4 from public.class_feature_picks)                     as four_steps,
  (select count(*) = 1 from public.schema_migrations
    where version = '122')                                                   as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the allowance, through RLS as the player
-- ---------------------------------------------------------------------------
--
-- Nat's starting entry becomes a level-3 Battle Master (as the table owner),
-- then Nat adds maneuvers the way the client does.
--
-- CORRECT OUTPUT: six rows.
--   target_found     true
--   three_at_3       ok      three maneuvers fit at 3rd level
--   fourth_at_3      refused (23514)
--   fourth_at_7      ok      after the level rises to 7
--   second_style     refused (23514)   Fighting Style still allows one
--   after_level_drop 4       a level drop to 3 keeps every pick

begin;

select set_config(
  'verification.entry',
  (select cc.id::text from public.character_classes cc
     join public.characters c on c.id = cc.character_id
    where c.campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
      and c.user_id = '1313672b-6990-45a6-8a28-c448ca116d2d'
    order by cc.is_starting desc
    limit 1),
  true
);

update public.character_classes
   set class_id = (select id from public.classes where name = 'Fighter' and campaign_id is null),
       subclass_id = null
 where id = nullif(current_setting('verification.entry'), '')::uuid;
update public.character_classes
   set level = 3,
       subclass_id = (select s.id from public.subclasses s join public.classes k on k.id = s.class_id
                       where k.name = 'Fighter' and k.campaign_id is null and s.name = 'Battle Master')
 where id = nullif(current_setting('verification.entry'), '')::uuid;

set local role authenticated;

do $$
declare
  v_entry uuid := nullif(current_setting('verification.entry'), '')::uuid;
  v_char  uuid;
  v_class uuid;
  v_cs    uuid;
  v_style uuid;
  v_key   text;
begin
  if v_entry is null then return; end if;
  perform set_config('request.jwt.claims',
    '{"sub":"1313672b-6990-45a6-8a28-c448ca116d2d","role":"authenticated"}', true);

  select character_id, class_id into v_char, v_class from character_classes where id = v_entry;
  select id into v_cs from class_features
   where class_id = v_class and name = 'Combat Superiority' and campaign_id is null;
  select id into v_style from class_features
   where class_id = v_class and name = 'Fighting Style' and campaign_id is null;

  foreach v_key in array array['parry', 'riposte', 'trip_attack'] loop
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_cs,
            (select id from feature_options where key = v_key and campaign_id is null));
  end loop;
  perform set_config('verification.three_at_3', 'ok', true);

  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_cs,
            (select id from feature_options where key = 'rally' and campaign_id is null));
    perform set_config('verification.fourth_at_3', 'ACCEPTED -- LIMIT MISSING', true);
  exception when check_violation then
    perform set_config('verification.fourth_at_3', 'refused (23514)', true);
  end;

  update character_classes set level = 7 where id = v_entry;
  insert into character_feature_choices
    (character_id, character_class_id, class_id, feature_id, option_id)
  values (v_char, v_entry, v_class, v_cs,
          (select id from feature_options where key = 'rally' and campaign_id is null));
  perform set_config('verification.fourth_at_7', 'ok', true);

  insert into character_feature_choices
    (character_id, character_class_id, class_id, feature_id, option_id)
  values (v_char, v_entry, v_class, v_style,
          (select id from feature_options where key = 'archery' and campaign_id is null));
  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_style,
            (select id from feature_options where key = 'defense' and campaign_id is null));
    perform set_config('verification.second_style', 'ACCEPTED -- LIMIT MISSING', true);
  exception when check_violation then
    perform set_config('verification.second_style', 'refused (23514)', true);
  end;

  update character_classes set level = 3 where id = v_entry;
  perform set_config('verification.after_level_drop',
    (select count(*) from character_feature_choices
      where character_class_id = v_entry and feature_id = v_cs)::text, true);
end
$$;

reset role;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'target_found',     nullif(current_setting('verification.entry', true), '') is not null,
         'three_at_3',       current_setting('verification.three_at_3', true),
         'fourth_at_3',      current_setting('verification.fourth_at_3', true),
         'fourth_at_7',      current_setting('verification.fourth_at_7', true),
         'second_style',     current_setting('verification.second_style', true),
         'after_level_drop', current_setting('verification.after_level_drop', true)
       ));

rollback;
