-- db/083_feature_choices.sql
--
-- Per-character picks for class features, replacing 079's one-column design.
-- 079's header named the trigger ("when maneuvers or invocations arrive");
-- 082 met it, and the party's Warlock, Sorcerer and Ranger are next. RUN 082
-- FIRST.
--
-- FOUR TABLES:
--
--   feature_options          the catalogue of things a feature lets you pick:
--                            fighting styles now; maneuvers, invocations,
--                            metamagic later. 054's shared-or-mine split.
--   class_feature_options    which options a given feature offers. This is
--                            what lets a Ranger's Fighting Style offer a
--                            subset of the Fighter's, with no code change.
--   class_feature_picks      how many picks a feature allows from a class
--                            level on. No row means one. Client-enforced only.
--   character_feature_choices  the picks.
--
-- WHY A CATALOGUE AND NOT `choice text` ON THE PICK. A free-text pick turns
-- 079's "one list in two places" (the CHECK and FIGHTING_STYLES) into one
-- such pair per kind of choice, and leaves no room for a DM's homebrew option.
-- 054's rule again: a table, not a map in code. Code keeps only the `key`s it
-- gives a mechanical effect to (Defense's +1 AC); the text lives here.
--
-- character_feature_choices:
--   * THREE COMPOSITE FKs carry the integrity, 056's trick, so a bad pick is
--     unrepresentable rather than cleaned up:
--       (character_class_id, character_id, class_id) -> character_classes
--           the pick can't drift from its character or its class.
--       (feature_id, class_id) -> class_features
--           a Fighter feature can't be picked on a Wizard entry.
--       (feature_id, option_id) -> class_feature_options
--           only an option the feature offers; replaces 079's CHECK.
--     The first two need new unique constraints on their targets. Both are
--     trivially satisfied (each contains the target's primary key).
--   * character_id is stored, not joined, so the policies are 056's
--     can_edit_character(character_id) and the sheet reads picks with one
--     .eq('character_id', ...). The first FK keeps it honest.
--   * unique (character_class_id, option_id, detail) NULLS NOT DISTINCT: no
--     option twice on one class entry ("You can't take the same Fighting
--     Style option more than once"), which is what makes Champion's
--     Additional Fighting Style safe to link to the same eleven. `detail`
--     takes part so a PHB Ranger can take Favored Enemy: humanoids twice for
--     two different pairs of races. The rule says "even across classes"; a
--     Fighter/Ranger repeat is left to the client.
--   * `detail` is the free-text half of a pick: Favored Enemy's two humanoid
--     races. Null for everything seeded here.
--   * NO UPDATE POLICY, so 037's three-policy shape, not 046's four: changing
--     a pick is delete-and-insert. With nothing updatable there is nothing to
--     pin, so no pin trigger and none of the blocklist problem (CLAUDE.md).
--   * The INSERT check also requires the option to be shared or the
--     character's own campaign's. RLS alone would let a member of two
--     campaigns attach one campaign's homebrew to the other's sheet (the
--     KNOWN_ISSUES entry for classes and races; closed here for options).
--
-- TRIGGERS ON character_classes:
--   * clear_stale_feature_choices, BEFORE UPDATE OF class_id, subclass_id. A
--     class change deletes the entry's picks; a subclass change deletes the
--     picks of subclass features. Today the client clears fighting_style and
--     the database wouldn't stop a Wizard holding Defense (setStartingClass's
--     own comment). Now it can't happen: and if this trigger were ever
--     missing, the first FK (NO ACTION) would refuse the class change rather
--     than leave stale picks.
--   * A LEVEL DROP DELIBERATELY CLEARS NOTHING. Picks above the new level stay
--     stored and the sheet's `f.level <= entry.level` hides them; correcting a
--     mis-set level brings them back.
--   * mirror_fighting_style, AFTER UPDATE OF fighting_style. TEMPORARY, dropped
--     by 084. The client deploys from main, so between this file and that
--     merge the old client still writes the column; the trigger copies each
--     write into the pick table so nothing written in the gap is lost. The new
--     client never writes the column, so this never fires once it's live.
--
-- 082's Additional Fighting Style text told the player to note the second
-- style by hand, because the column had room for one. It's a real picker now,
-- so the text goes back to the SRD's sentence alone.
--
-- BACKFILL. One pick per non-null fighting_style, on the class's shared
-- 'fighting_style' feature. Asserted: every non-null style must map, or the
-- whole file rolls back (050's lesson: a join that matches nothing succeeds).
--
-- 084 DROPS character_classes.fighting_style, class_features.choice and the
-- mirror trigger. Apply it only after the new client is live.
--
-- THE SQL EDITOR WILL OFFER "Run and enable RLS". This file enables RLS on its
-- own tables; take the option that runs WITHOUT enabling, as for 079.
--
-- AFTERWARDS: `notify pgrst, 'reload schema';` then `npm run gen:types`.


-- ===========================================================================
-- MIGRATION
-- ===========================================================================
--
-- CORRECT OUTPUT: "Success. No rows returned."

begin;

-- ---------- feature_options ----------

create table public.feature_options (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid references public.campaigns(id) on delete cascade,

  -- What sort of thing this is. Grows a value per seeded kind.
  kind text not null check (kind in ('fighting_style')),
  -- Stable identifier for code that gives the option an effect. Shared rows
  -- must have one; homebrew may not, and simply has no automatic effect.
  key text check (key ~ '^[a-z][a-z0-9_]*$'),
  name text not null check (length(btrim(name)) between 1 and 80),
  description text not null,
  -- Display only, like feats.prerequisite: "5th level", "Pact of the Blade".
  prerequisite text,
  -- 066's list. Null for homebrew.
  source text check (source in ('phb', 'xgte', 'tcoe')),

  created_at timestamptz not null default now(),

  check (campaign_id is not null or key is not null)
);

create unique index feature_options_shared_key
  on public.feature_options (kind, key)
  where campaign_id is null;

create unique index feature_options_shared_name
  on public.feature_options (kind, name)
  where campaign_id is null;

create index on public.feature_options (campaign_id);

alter table public.feature_options enable row level security;

create policy "read shared and own-campaign feature options"
  on public.feature_options for select to authenticated
  using (campaign_id is null or public.is_campaign_member(campaign_id));

create policy "dms create homebrew feature options"
  on public.feature_options for insert to authenticated
  with check (campaign_id is not null and public.is_campaign_dm(campaign_id));

-- ---------- class_feature_options ----------

create table public.class_feature_options (
  feature_id uuid not null references public.class_features(id) on delete cascade,
  option_id uuid not null references public.feature_options(id) on delete cascade,
  primary key (feature_id, option_id)
);

create index on public.class_feature_options (option_id);

alter table public.class_feature_options enable row level security;

-- Visible when both ends are: a campaign's homebrew style linked to the
-- shared Fighting Style stays out of every other campaign's read.
create policy "read links between visible features and options"
  on public.class_feature_options for select to authenticated
  using (
    exists (select 1 from class_features f where f.id = class_feature_options.feature_id)
    and exists (select 1 from feature_options o where o.id = class_feature_options.option_id)
  );

-- A DM links within their own campaign: a homebrew option to a shared or
-- own feature, or a shared option to an own (homebrew-class) feature. Never
-- shared to shared, and never across two campaigns.
create policy "dms link homebrew feature options"
  on public.class_feature_options for insert to authenticated
  with check (
    exists (
      select 1
        from feature_options o, class_features f
       where o.id = class_feature_options.option_id
         and f.id = class_feature_options.feature_id
         and coalesce(o.campaign_id, f.campaign_id) is not null
         and public.is_campaign_dm(coalesce(o.campaign_id, f.campaign_id))
         and (o.campaign_id is null or f.campaign_id is null
              or o.campaign_id = f.campaign_id)
    )
  );

-- ---------- class_feature_picks ----------

-- A step function: from class level `level` on, the feature allows `total`
-- picks. Combat Superiority will read (3,3) (7,5) (10,7) (15,9).
create table public.class_feature_picks (
  feature_id uuid not null references public.class_features(id) on delete cascade,
  level smallint not null check (level between 1 and 20),
  total smallint not null check (total between 1 and 30),
  primary key (feature_id, level)
);

alter table public.class_feature_picks enable row level security;

create policy "read picks of visible features"
  on public.class_feature_picks for select to authenticated
  using (exists (select 1 from class_features f where f.id = class_feature_picks.feature_id));

create policy "dms set picks on homebrew features"
  on public.class_feature_picks for insert to authenticated
  with check (
    exists (
      select 1 from class_features f
       where f.id = class_feature_picks.feature_id
         and f.campaign_id is not null
         and public.is_campaign_dm(f.campaign_id)
    )
  );

-- ---------- character_feature_choices ----------

alter table public.character_classes
  add constraint character_classes_id_character_class_key
  unique (id, character_id, class_id);

alter table public.class_features
  add constraint class_features_id_class_key
  unique (id, class_id);

create table public.character_feature_choices (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null,
  character_class_id uuid not null,
  class_id uuid not null,
  feature_id uuid not null,
  option_id uuid not null,
  detail text check (detail is null or length(btrim(detail)) between 1 and 200),

  created_at timestamptz not null default now(),

  foreign key (character_class_id, character_id, class_id)
    references public.character_classes (id, character_id, class_id)
    on delete cascade,
  foreign key (feature_id, class_id)
    references public.class_features (id, class_id)
    on delete cascade,
  foreign key (feature_id, option_id)
    references public.class_feature_options (feature_id, option_id)
    on delete cascade
);

create unique index character_feature_choices_once
  on public.character_feature_choices (character_class_id, option_id, detail)
  nulls not distinct;

create index on public.character_feature_choices (character_id);
create index on public.character_feature_choices (feature_id, option_id);

alter table public.character_feature_choices enable row level security;

create policy "character viewers read feature choices"
  on public.character_feature_choices for select to authenticated
  using (
    exists (
      select 1 from characters c
      where c.id = character_feature_choices.character_id
    )
  );

create policy "owner or dm adds feature choices"
  on public.character_feature_choices for insert to authenticated
  with check (
    public.can_edit_character(character_id)
    and exists (
      select 1
        from feature_options o, characters c
       where o.id = character_feature_choices.option_id
         and c.id = character_feature_choices.character_id
         and (o.campaign_id is null or o.campaign_id = c.campaign_id)
    )
  );

create policy "owner or dm removes feature choices"
  on public.character_feature_choices for delete to authenticated
  using (public.can_edit_character(character_id));

-- ---------- the triggers on character_classes ----------

create or replace function public.clear_stale_feature_choices()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
begin
  if new.class_id is distinct from old.class_id then
    delete from character_feature_choices
     where character_class_id = old.id;
  elsif new.subclass_id is distinct from old.subclass_id then
    delete from character_feature_choices ch
     using class_features f
     where ch.character_class_id = old.id
       and f.id = ch.feature_id
       and f.subclass_id is not null;
  end if;
  return new;
end;
$function$
;

create trigger clear_stale_feature_choices
  before update of class_id, subclass_id on public.character_classes
  for each row execute function public.clear_stale_feature_choices();

-- TEMPORARY: 084 drops it with the column.
create or replace function public.mirror_fighting_style()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
begin
  delete from character_feature_choices ch
   using class_features f
   where ch.character_class_id = new.id
     and f.id = ch.feature_id
     and f.choice = 'fighting_style';

  if new.fighting_style is not null then
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    select new.character_id, new.id, new.class_id, f.id, o.id
      from class_features f
      join class_feature_options l on l.feature_id = f.id
      join feature_options o on o.id = l.option_id
     where f.class_id = new.class_id
       and f.choice = 'fighting_style'
       and o.kind = 'fighting_style'
       and o.key = new.fighting_style
       and o.campaign_id is null;
  end if;
  return new;
end;
$function$
;

create trigger mirror_fighting_style
  after update of fighting_style on public.character_classes
  for each row
  when (new.fighting_style is distinct from old.fighting_style)
  execute function public.mirror_fighting_style();

-- ---------- seed, link, backfill ----------

do $$
declare
  -- The one place each literal is named. Nothing below repeats them.
  c_class          constant text := 'Fighter';
  c_champion       constant text := 'Champion';
  c_style          constant text := 'Fighting Style';
  c_additional     constant text := 'Additional Fighting Style';
  c_expected_opts  constant int  := 11;

  v_seeking    text;
  v_class      uuid;
  v_champion   uuid;
  v_style      uuid;
  v_additional uuid;
  v_count      int;
  v_unmapped   int;
  v_updated    int;
begin
  v_seeking := format('shared class "%s"', c_class);
  select id into strict v_class
    from public.classes where name = c_class and campaign_id is null;

  v_seeking := format('%s subclass "%s"', c_class, c_champion);
  select id into strict v_champion
    from public.subclasses
   where class_id = v_class and name = c_champion and campaign_id is null;

  v_seeking := format('%s feature "%s"', c_class, c_style);
  select id into strict v_style
    from public.class_features
   where class_id = v_class and subclass_id is null and name = c_style
     and campaign_id is null;

  v_seeking := format('%s feature "%s"', c_champion, c_additional);
  select id into strict v_additional
    from public.class_features
   where class_id = v_class and subclass_id = v_champion and name = c_additional
     and campaign_id is null;

  -- FIGHTING_STYLES' text, moved here; the keys are unchanged.
  insert into public.feature_options (kind, key, name, source, description)
  values
    ('fighting_style', 'archery', 'Archery', 'phb',
     'You gain a +2 bonus to attack rolls you make with ranged weapons.'),
    ('fighting_style', 'defense', 'Defense', 'phb',
     'While you are wearing armor, you gain a +1 bonus to AC.'),
    ('fighting_style', 'dueling', 'Dueling', 'phb',
     'When you are wielding a melee weapon in one hand and no other weapons, '
     'you gain a +2 bonus to damage rolls with that weapon.'),
    ('fighting_style', 'great_weapon', 'Great Weapon Fighting', 'phb',
     'When you roll a 1 or 2 on a damage die for an attack you make with a '
     'melee weapon that you are wielding with two hands, you can reroll the '
     'die and must use the new roll. The weapon must have the two-handed or '
     'versatile property.'),
    ('fighting_style', 'protection', 'Protection', 'phb',
     'When a creature you can see attacks a target other than you that is '
     'within 5 feet of you, you can use your reaction to impose disadvantage '
     'on the attack roll. You must be wielding a shield.'),
    ('fighting_style', 'two_weapon', 'Two-Weapon Fighting', 'phb',
     'When you engage in two-weapon fighting, you can add your ability '
     'modifier to the damage of the second attack.'),
    ('fighting_style', 'blind_fighting', 'Blind Fighting', 'tcoe',
     'You have blindsight with a range of 10 feet. Within that range, you can '
     'effectively see anything that isn''t behind total cover, even if you''re '
     'blinded or in darkness, and you can see an invisible creature unless it '
     'successfully hides from you.'),
    ('fighting_style', 'interception', 'Interception', 'tcoe',
     'When a creature you can see hits a target, other than you, within 5 '
     'feet of you with an attack, you can use your reaction to reduce the '
     'damage by 1d10 + your proficiency bonus. You must be wielding a shield '
     'or a simple or martial weapon.'),
    ('fighting_style', 'superior_technique', 'Superior Technique', 'tcoe',
     'You learn one maneuver from the Battle Master archetype (save DC 8 + '
     'proficiency bonus + Strength or Dexterity modifier). You gain one '
     'superiority die, a d6, regained on a short or long rest.'),
    ('fighting_style', 'thrown_weapon', 'Thrown Weapon Fighting', 'tcoe',
     'You can draw a weapon that has the thrown property as part of the '
     'attack you make with it. When you hit with a ranged attack using a '
     'thrown weapon, you gain a +2 bonus to the damage roll.'),
    ('fighting_style', 'unarmed', 'Unarmed Fighting', 'tcoe',
     'Your unarmed strikes deal 1d6 + Strength bludgeoning damage on a hit, or '
     '1d8 if you aren''t wielding any weapons or a shield. At the start of each '
     'of your turns, you can deal 1d4 bludgeoning damage to one creature '
     'grappled by you.');

  -- The Fighter gets all eleven, at level 1 and again at Champion 10.
  insert into public.class_feature_options (feature_id, option_id)
  select f.id, o.id
    from (values (v_style), (v_additional)) as f(id)
   cross join public.feature_options o
   where o.kind = 'fighting_style' and o.campaign_id is null;

  update public.class_features
     set description =
       'At 10th level, you can choose a second option from the Fighting Style '
       'class feature.'
   where id = v_additional;
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'Rewrote % Additional Fighting Style rows (expected 1). Rolled back.', v_updated;
  end if;

  -- One pick per non-null style, on the class's own Fighting Style feature.
  insert into public.character_feature_choices
    (character_id, character_class_id, class_id, feature_id, option_id)
  select cc.character_id, cc.id, cc.class_id, f.id, o.id
    from public.character_classes cc
    join public.class_features f
      on f.class_id = cc.class_id and f.choice = 'fighting_style'
     and f.campaign_id is null
    join public.class_feature_options l on l.feature_id = f.id
    join public.feature_options o
      on o.id = l.option_id and o.key = cc.fighting_style
   where cc.fighting_style is not null;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
    from public.feature_options
   where kind = 'fighting_style' and campaign_id is null;
  if v_count <> c_expected_opts then
    raise exception '% shared fighting styles (expected %). Rolled back.',
      v_count, c_expected_opts;
  end if;

  select count(*) into v_count
    from public.class_feature_options
   where feature_id in (v_style, v_additional);
  if v_count <> 2 * c_expected_opts then
    raise exception '% links on the two Fighter style features (expected %). Rolled back.',
      v_count, 2 * c_expected_opts;
  end if;

  select count(*) into v_unmapped
    from public.character_classes cc
   where cc.fighting_style is not null
     and not exists (
       select 1 from public.character_feature_choices ch
         join public.class_features f on f.id = ch.feature_id
         join public.feature_options o on o.id = ch.option_id
        where ch.character_class_id = cc.id
          and f.choice = 'fighting_style'
          and o.key = cc.fighting_style
     );
  if v_unmapped <> 0 then
    raise exception
      '% class entries hold a fighting_style that has no pick after the backfill (a class with no seeded Fighting Style feature?). Check: select id, class_id, fighting_style from character_classes where fighting_style is not null; Rolled back.',
      v_unmapped;
  end if;
exception
  when no_data_found then
    raise exception 'Found no %. 055/071/080/082 seed it. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one %. Resolve the duplicate first. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('083');

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
--
-- BLOCKS 2-5 make Nat a level-10 Champion inside the block (as the table
-- owner) so they run whatever Nat's sheet holds today. They need Nat to have
-- a character in A; target_found = false means he has none.


-- ---------------------------------------------------------------------------
-- BLOCK 0: the objects exist
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, every column `t`.

begin;

select
  (select count(*) = 2 from pg_policies
    where schemaname = 'public' and tablename = 'feature_options')           as opt_policies,
  (select count(*) = 2 from pg_policies
    where schemaname = 'public' and tablename = 'class_feature_options')     as link_policies,
  (select count(*) = 2 from pg_policies
    where schemaname = 'public' and tablename = 'class_feature_picks')       as picks_policies,
  (select count(*) = 3 from pg_policies
    where schemaname = 'public' and tablename = 'character_feature_choices') as choice_policies,
  (select bool_and(relrowsecurity) from pg_class
    where oid in ('public.feature_options'::regclass,
                  'public.class_feature_options'::regclass,
                  'public.class_feature_picks'::regclass,
                  'public.character_feature_choices'::regclass))             as rls_on,
  (select count(*) = 2 from pg_trigger
    where tgrelid = 'public.character_classes'::regclass
      and tgname in ('clear_stale_feature_choices', 'mirror_fighting_style')) as triggers,
  (select count(*) = 11 from public.feature_options
    where kind = 'fighting_style' and campaign_id is null)                   as eleven_styles,
  (select count(*) = 22 from public.class_feature_options)                   as twenty_two_links,
  (select count(*) = 1 from public.schema_migrations
    where version = '083')                                                   as ledger_row;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 1: the backfill matched every style
-- ---------------------------------------------------------------------------
--
-- CORRECT OUTPUT: one row, styles = picks (both 0 is fine: nobody had picked).

begin;

select
  (select count(*) from public.character_classes
    where fighting_style is not null)                                       as styles,
  (select count(*) from public.character_feature_choices ch
     join public.class_features f on f.id = ch.feature_id
    where f.choice = 'fighting_style')                                      as picks;

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 2: owner, DM and a stranger each try to add a pick
-- ---------------------------------------------------------------------------
--
-- 079 BLOCK 2's shape on the new table. A refused INSERT raises 42501, so each
-- is caught and reported.
--
-- CORRECT OUTPUT: target_found = true, owner = 'ok', dm = 'ok',
-- stranger = 'refused', picks_now = 2.

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

-- As the owner: make the entry a level-10 Champion with no picks.
update public.character_classes
   set class_id = (select id from public.classes where name = 'Fighter' and campaign_id is null),
       subclass_id = null, fighting_style = null
 where id = nullif(current_setting('verification.entry'), '')::uuid;
update public.character_classes
   set level = 10,
       subclass_id = (select s.id from public.subclasses s join public.classes k on k.id = s.class_id
                       where k.name = 'Fighter' and k.campaign_id is null and s.name = 'Champion')
 where id = nullif(current_setting('verification.entry'), '')::uuid;

set local role authenticated;

do $$
declare
  v_entry uuid := nullif(current_setting('verification.entry'), '')::uuid;
  v_char  uuid;
  v_class uuid;
  v_style uuid;
  v_add   uuid;
  v_arch  uuid;
  v_def   uuid;
  v_dual  uuid;
begin
  if v_entry is null then return; end if;

  perform set_config('request.jwt.claims',
    '{"sub":"1313672b-6990-45a6-8a28-c448ca116d2d","role":"authenticated"}', true);
  select character_id, class_id into v_char, v_class
    from character_classes where id = v_entry;
  select id into v_style from class_features
   where class_id = v_class and name = 'Fighting Style';
  select id into v_add from class_features
   where class_id = v_class and name = 'Additional Fighting Style';
  select id into v_arch from feature_options where key = 'archery';
  select id into v_def  from feature_options where key = 'defense';
  select id into v_dual from feature_options where key = 'dueling';

  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_style, v_arch);
    perform set_config('verification.owner', 'ok', true);
  exception when insufficient_privilege then
    perform set_config('verification.owner', 'REFUSED -- should have passed', true);
  end;

  perform set_config('request.jwt.claims',
    '{"sub":"ea74d56b-8f45-4e4c-80f8-90a6d29b5adf","role":"authenticated"}', true);
  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_add, v_def);
    perform set_config('verification.dm', 'ok', true);
  exception when insufficient_privilege then
    perform set_config('verification.dm', 'REFUSED -- should have passed', true);
  end;

  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_add, v_dual);
    perform set_config('verification.stranger', 'ACCEPTED -- POLICY MISSING', true);
  exception when insufficient_privilege then
    perform set_config('verification.stranger', 'refused', true);
  end;
end
$$;

reset role;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'target_found', nullif(current_setting('verification.entry', true), '') is not null,
         'owner',        current_setting('verification.owner', true),
         'dm',           current_setting('verification.dm', true),
         'stranger',     current_setting('verification.stranger', true),
         'picks_now',    (select count(*) from public.character_feature_choices
                           where character_class_id = nullif(current_setting('verification.entry'), '')::uuid)
       ));

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 3: the constraints refuse each bad pick
-- ---------------------------------------------------------------------------
--
-- Runs as the table owner: this is about the FKs and the unique index, not
-- RLS. Archery on Fighting Style, then four bad inserts. The two FK cases use
-- Defense, which isn't picked, so the unique index can't fire first and mask
-- a missing FK.
--
-- CORRECT OUTPUT: four rows, every result 'refused'.
--   duplicate        Archery again, on Additional Fighting Style
--   not_offered      a made-up option the feature doesn't link
--   wrong_class      the Fighter's Fighting Style, Defense, claiming class Wizard
--   wrong_character  Defense on the entry's id with another character's id

begin;

do $$
declare
  v_entry  uuid;
  v_char   uuid;
  v_class  uuid;
  v_wizard uuid;
  v_style  uuid;
  v_add    uuid;
  v_arch   uuid;
  v_def    uuid;
  v_fake   uuid;
begin
  select cc.id, cc.character_id into v_entry, v_char
    from character_classes cc join characters c on c.id = cc.character_id
   where c.campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
     and c.user_id = '1313672b-6990-45a6-8a28-c448ca116d2d'
   order by cc.is_starting desc limit 1;
  if v_entry is null then
    perform set_config('verification.duplicate', 'skipped: Nat has no class entry', true);
    perform set_config('verification.not_offered', 'skipped', true);
    perform set_config('verification.wrong_class', 'skipped', true);
    perform set_config('verification.wrong_character', 'skipped', true);
    return;
  end if;

  select id into v_class  from classes where name = 'Fighter' and campaign_id is null;
  select id into v_wizard from classes where name = 'Wizard'  and campaign_id is null;
  update character_classes set class_id = v_class, subclass_id = null, fighting_style = null where id = v_entry;
  select id into v_style from class_features where class_id = v_class and name = 'Fighting Style';
  select id into v_add   from class_features where class_id = v_class and name = 'Additional Fighting Style';
  select id into v_arch  from feature_options where key = 'archery';
  select id into v_def   from feature_options where key = 'defense';

  insert into feature_options (campaign_id, kind, name, description)
  values ('d721b412-2750-492e-bddd-7387fc464bba', 'fighting_style', 'Kung Fu', 'Rolled back.')
  returning id into v_fake;

  insert into character_feature_choices
    (character_id, character_class_id, class_id, feature_id, option_id)
  values (v_char, v_entry, v_class, v_style, v_arch);

  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_add, v_arch);
    perform set_config('verification.duplicate', 'ACCEPTED -- UNIQUE MISSING', true);
  exception when unique_violation then
    perform set_config('verification.duplicate', 'refused', true);
  end;

  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_style, v_fake);
    perform set_config('verification.not_offered', 'ACCEPTED -- FK MISSING', true);
  exception when foreign_key_violation then
    perform set_config('verification.not_offered', 'refused', true);
  end;

  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_wizard, v_style, v_def);
    perform set_config('verification.wrong_class', 'ACCEPTED -- FK MISSING', true);
  exception when foreign_key_violation then
    perform set_config('verification.wrong_class', 'refused', true);
  end;

  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (gen_random_uuid(), v_entry, v_class, v_add, v_def);
    perform set_config('verification.wrong_character', 'ACCEPTED -- FK MISSING', true);
  exception when foreign_key_violation then
    perform set_config('verification.wrong_character', 'refused', true);
  end;
end
$$;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'duplicate',       current_setting('verification.duplicate'),
         'not_offered',     current_setting('verification.not_offered'),
         'wrong_class',     current_setting('verification.wrong_class'),
         'wrong_character', current_setting('verification.wrong_character')
       ));

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 4: a subclass change clears subclass picks; a class change clears all
-- ---------------------------------------------------------------------------
--
-- As the table owner. Champion 10 with Archery (class feature) and Defense
-- (Champion feature), then the subclass is cleared, then the class changed.
--
-- CORRECT OUTPUT: target_found = true, before = 2, after_subclass = 1,
-- after_class = 0.

begin;

do $$
declare
  v_entry uuid;
  v_char  uuid;
  v_class uuid;
  v_champ uuid;
begin
  select cc.id, cc.character_id into v_entry, v_char
    from character_classes cc join characters c on c.id = cc.character_id
   where c.campaign_id = 'd721b412-2750-492e-bddd-7387fc464bba'
     and c.user_id = '1313672b-6990-45a6-8a28-c448ca116d2d'
   order by cc.is_starting desc limit 1;
  perform set_config('verification.found', (v_entry is not null)::text, true);
  if v_entry is null then return; end if;

  select id into v_class from classes where name = 'Fighter' and campaign_id is null;
  select id into v_champ from subclasses where class_id = v_class and name = 'Champion';
  update character_classes set class_id = v_class, subclass_id = null, fighting_style = null where id = v_entry;
  update character_classes set subclass_id = v_champ, level = 10 where id = v_entry;

  insert into character_feature_choices
    (character_id, character_class_id, class_id, feature_id, option_id)
  select v_char, v_entry, v_class, f.id, o.id
    from class_features f, feature_options o
   where f.class_id = v_class
     and ((f.name = 'Fighting Style' and o.key = 'archery')
       or (f.name = 'Additional Fighting Style' and o.key = 'defense'));
  perform set_config('verification.before',
    (select count(*) from character_feature_choices where character_class_id = v_entry)::text, true);

  update character_classes set subclass_id = null where id = v_entry;
  perform set_config('verification.after_subclass',
    (select count(*) from character_feature_choices where character_class_id = v_entry)::text, true);

  update character_classes
     set class_id = (select id from classes where name = 'Wizard' and campaign_id is null)
   where id = v_entry;
  perform set_config('verification.after_class',
    (select count(*) from character_feature_choices where character_class_id = v_entry)::text, true);
end
$$;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'target_found',   current_setting('verification.found'),
         'before',         current_setting('verification.before', true),
         'after_subclass', current_setting('verification.after_subclass', true),
         'after_class',    current_setting('verification.after_class', true)
       ));

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 5: the old client's write is mirrored (until 084)
-- ---------------------------------------------------------------------------
--
-- As Nat, through RLS, the way the old client writes: set the column, change
-- it, clear it.
--
-- CORRECT OUTPUT: target_found = true, after_set = 'archery',
-- after_change = 'dueling', after_clear = '' (no pick).

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
       subclass_id = null, fighting_style = null
 where id = nullif(current_setting('verification.entry'), '')::uuid;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"1313672b-6990-45a6-8a28-c448ca116d2d","role":"authenticated"}', true);

update public.character_classes set fighting_style = 'archery'
 where id = nullif(current_setting('verification.entry'), '')::uuid;
select set_config('verification.after_set', coalesce(string_agg(o.key, ','), ''), true)
  from public.character_feature_choices ch join public.feature_options o on o.id = ch.option_id
 where ch.character_class_id = nullif(current_setting('verification.entry'), '')::uuid;

update public.character_classes set fighting_style = 'dueling'
 where id = nullif(current_setting('verification.entry'), '')::uuid;
select set_config('verification.after_change', coalesce(string_agg(o.key, ','), ''), true)
  from public.character_feature_choices ch join public.feature_options o on o.id = ch.option_id
 where ch.character_class_id = nullif(current_setting('verification.entry'), '')::uuid;

update public.character_classes set fighting_style = null
 where id = nullif(current_setting('verification.entry'), '')::uuid;
select set_config('verification.after_clear', coalesce(string_agg(o.key, ','), ''), true)
  from public.character_feature_choices ch join public.feature_options o on o.id = ch.option_id
 where ch.character_class_id = nullif(current_setting('verification.entry'), '')::uuid;

reset role;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'target_found', nullif(current_setting('verification.entry', true), '') is not null,
         'after_set',    current_setting('verification.after_set'),
         'after_change', current_setting('verification.after_change'),
         'after_clear',  current_setting('verification.after_clear')
       ));

rollback;
