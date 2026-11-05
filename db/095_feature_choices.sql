-- db/095_feature_choices.sql
--
-- Per-character picks for class features, replacing the one-column design
-- (079's character_classes.fighting_style, 083's per-row array). The trigger
-- KNOWN_ISSUES named has arrived: Champion's Additional Fighting Style (082)
-- has nowhere to store a second style, and Battle Master maneuvers, Arcane
-- Shots and runes all want many picks per feature.
--
-- Rebuilt from the design on the remote branch feat/feature-choices, which
-- was written against 082 and can't be rebased (KNOWN_ISSUES). That branch
-- had four tables; this file has three. Its `class_feature_picks` (how many
-- picks a feature allows per level) is left out: every feature seeded today
-- allows exactly one pick, and the table can arrive with maneuvers, when
-- something actually reads it.
--
-- EXPAND, THEN CONTRACT. This is the expand half. The client deploys from
-- main, so for a while after this file runs the old client is still live and
-- still writes character_classes.fighting_style. A temporary trigger copies
-- each of those writes into the new table, so a player with an old tab open
-- can't lose a pick. 096 drops the old columns and that trigger, and runs only
-- after the new client is merged.
--
-- THREE TABLES:
--
--   feature_options            the catalogue of things a feature lets you
--                              pick. Fighting styles now; maneuvers,
--                              invocations and metamagic later. 054's
--                              shared-or-mine split, and its two policies.
--   class_feature_options      which options a feature offers. It replaces
--                              083's fighting_style_options array. A link
--                              table rather than an array of ids because an
--                              FK can point at it (below), and an array
--                              element can't be FK-checked.
--   character_feature_choices  the picks.
--
-- WHY A CATALOGUE, NOT A KEY STORED ON THE PICK. A free-text key turns "the
-- domain and FIGHTING_STYLES are one list in two places" into one such pair
-- per kind of choice, and leaves nowhere for a DM's homebrew option. With the
-- catalogue, the style text moves out of rules.ts into the table, and code
-- keeps only the `key`s it gives a mechanical effect to (defense, archery).
-- `kind` stays a CHECK, small and closed like feats.category, and is one list
-- in two places with FEATURE_OPTION_KINDS in services/classes.ts.
--
-- character_feature_choices:
--   * THREE COMPOSITE FKs carry the integrity, so a bad pick is
--     unrepresentable rather than cleaned up afterwards:
--       (character_class_id, character_id, class_id) -> character_classes
--           the pick can't drift from its character or its class.
--       (feature_id, class_id) -> class_features
--           a Fighter feature can't be picked on a Wizard entry.
--       (feature_id, option_id) -> class_feature_options
--           only an option the feature offers.
--     The first two need unique constraints on their targets that contain
--     the target's primary key, so they hold trivially.
--   * Not enforced: that a subclass feature matches the entry's subclass. A
--     Champion feature could be picked on a Battle Master entry by hand. The
--     sheet never offers it (it shows only the entry's subclass's features),
--     and the clear trigger below empties subclass picks on a subclass
--     change.
--   * character_id is stored, not joined, so the policies can be
--     can_edit_character(character_id) and the sheet reads picks with one
--     .eq(). The first FK keeps it honest.
--   * unique (character_class_id, feature_id): one pick per feature. That's
--     true of everything seeded today, and it's the upsert's conflict target.
--     Maneuvers will need it relaxed, together with the picks table.
--   * unique (character_id, option_id): the PHB's "you can't take a Fighting
--     Style option more than once, even if you later get to choose again".
--     Per character, not per class entry, because the rule spans classes (a
--     Fighter/Paladin can't take Defense twice). The old branch keyed this on
--     the class entry plus a free-text `detail` column, for Favored Enemy's
--     humanoid races; both wait until Favored Enemy gets a picker.
--   * FOUR POLICIES, 046's shape, not 037's three: changing a pick is an
--     upsert whose second write is an UPDATE (CLAUDE.md's upsert gotcha), so
--     the client saves without ignoreDuplicates and this table ships the
--     UPDATE policy for it.
--   * THE PIN TRIGGER IS AN ALLOWLIST. Every other pin in the app names the
--     columns an update may not touch, so it fails open when a column is
--     added (KNOWN_ISSUES). This one copies OLD over NEW and then restores
--     the one column an update may change, option_id, so a column added later
--     is pinned until someone decides otherwise.
--   * The INSERT and UPDATE checks also require the option to be shared or
--     the character's own campaign's. RLS alone would let a member of two
--     campaigns attach one campaign's homebrew option to the other's sheet.
--
-- TRIGGERS ON character_classes:
--   * clear_stale_feature_choices, BEFORE UPDATE OF class_id, subclass_id. A
--     class change deletes all of the entry's picks; a subclass change
--     deletes the picks of subclass features. Until now the client cleared
--     fighting_style itself (setStartingClass) and nothing stopped a Wizard
--     holding Defense. If this trigger were ever missing, the first FK (NO
--     ACTION) would refuse the class change rather than leave stale picks.
--     The function is security invoker: the picks it deletes are ones the
--     caller may edit, since both tables use can_edit_character.
--   * A level drop deliberately clears nothing. Picks above the new level
--     stay stored, and the sheet's `f.level <= entry.level` hides them;
--     correcting a mis-set level brings them back.
--   * mirror_fighting_style, AFTER UPDATE OF fighting_style. TEMPORARY, and
--     dropped by 096. It replaces the entry's pick on its base Fighting Style
--     feature (the row with choice = 'fighting_style') with whatever the old
--     client just wrote. The new client never writes the column, so this
--     stops firing once the new client is live.
--
-- SEED, LINK, BACKFILL:
--   * Thirteen shared options, the domain's thirteen keys, with text in our
--     own words (CLAUDE.md: feature text is a short summary, never the
--     book's).
--   * Every feature row's fighting_style_options array becomes links: the
--     Fighter's 11 and the Paladin's and Ranger's 7 each.
--   * Champion's Additional Fighting Style is linked to the Fighter's 11 and
--     becomes a real picker. It still has no `choice`, on purpose: the old
--     client renders a picker only for `choice = 'fighting_style'`, and that
--     picker writes the one column, so it would overwrite the first pick.
--     Its text drops 082's "note your second one yourself".
--   * One pick per non-null character_classes.fighting_style, on that class's
--     base Fighting Style feature.
--   Every step is asserted on the end state, so a join that matches nothing
--   rolls the file back (050's lesson).
--
-- THE SQL EDITOR WILL OFFER "Run and enable RLS". This file enables RLS on its
-- own tables; take the option that runs WITHOUT enabling (CLAUDE.md).
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

  -- What sort of thing this is. Grows a value per kind that gets a picker.
  kind text not null check (kind in ('fighting_style')),
  -- The stable name code uses to give an option an effect ('defense'). Every
  -- shared row has one; homebrew may leave it null and simply has no
  -- automatic effect.
  key text check (key ~ '^[a-z][a-z0-9_]*$'),
  name text not null check (length(btrim(name)) between 1 and 80),
  description text not null,
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

-- Visible when both ends are, so a campaign's homebrew style linked to a
-- shared feature stays out of every other campaign's read. Both subqueries
-- answer through their own table's SELECT policy (CLAUDE.md: fails closed).
create policy "read links between visible features and options"
  on public.class_feature_options for select to authenticated
  using (
    exists (select 1 from public.class_features f
             where f.id = class_feature_options.feature_id)
    and exists (select 1 from public.feature_options o
                 where o.id = class_feature_options.option_id)
  );

-- A DM links within their own campaign: a homebrew option to a shared or own
-- feature, or a shared option to an own (homebrew-class) feature. Never
-- shared to shared, and never across two campaigns.
create policy "dms link homebrew feature options"
  on public.class_feature_options for insert to authenticated
  with check (
    exists (
      select 1
        from public.feature_options o, public.class_features f
       where o.id = class_feature_options.option_id
         and f.id = class_feature_options.feature_id
         and coalesce(o.campaign_id, f.campaign_id) is not null
         and public.is_campaign_dm(coalesce(o.campaign_id, f.campaign_id))
         and (o.campaign_id is null or f.campaign_id is null
              or o.campaign_id = f.campaign_id)
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

  created_at timestamptz not null default now(),

  foreign key (character_class_id, character_id, class_id)
    references public.character_classes (id, character_id, class_id)
    on delete cascade,
  foreign key (feature_id, class_id)
    references public.class_features (id, class_id)
    on delete cascade,
  foreign key (feature_id, option_id)
    references public.class_feature_options (feature_id, option_id)
    on delete cascade,

  unique (character_class_id, feature_id),
  unique (character_id, option_id)
);

create index on public.character_feature_choices (feature_id, option_id);

alter table public.character_feature_choices enable row level security;

create policy "character viewers read feature choices"
  on public.character_feature_choices for select to authenticated
  using (
    exists (
      select 1 from public.characters c
       where c.id = character_feature_choices.character_id
    )
  );

create policy "owner or dm adds feature choices"
  on public.character_feature_choices for insert to authenticated
  with check (
    public.can_edit_character(character_id)
    and exists (
      select 1
        from public.feature_options o, public.characters c
       where o.id = character_feature_choices.option_id
         and c.id = character_feature_choices.character_id
         and (o.campaign_id is null or o.campaign_id = c.campaign_id)
    )
  );

create policy "owner or dm changes feature choices"
  on public.character_feature_choices for update to authenticated
  using (public.can_edit_character(character_id))
  with check (
    public.can_edit_character(character_id)
    and exists (
      select 1
        from public.feature_options o, public.characters c
       where o.id = character_feature_choices.option_id
         and c.id = character_feature_choices.character_id
         and (o.campaign_id is null or o.campaign_id = c.campaign_id)
    )
  );

create policy "owner or dm removes feature choices"
  on public.character_feature_choices for delete to authenticated
  using (public.can_edit_character(character_id));

-- The allowlist pin (header). `new := old` copies every column, so the only
-- change an UPDATE can make is the one restored after it.
create or replace function public.pin_character_feature_choice_row()
 returns trigger
 language plpgsql
 security invoker
 set search_path to 'public'
as $function$
declare
  v_option uuid := new.option_id;
begin
  new := old;
  new.option_id := v_option;
  return new;
end;
$function$
;

create trigger pin_character_feature_choice_row
  before update on public.character_feature_choices
  for each row execute function public.pin_character_feature_choice_row();

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

-- TEMPORARY: 096 drops it with the column.
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
  c_class         constant text := 'Fighter';
  c_champion      constant text := 'Champion';
  c_style         constant text := 'Fighting Style';
  c_additional    constant text := 'Additional Fighting Style';
  c_expected_opts constant int  := 13;

  v_seeking    text;
  v_class      uuid;
  v_champion   uuid;
  v_style      uuid;
  v_additional uuid;
  v_expected   int;
  v_count      int;
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

  -- The domain's thirteen keys. Summaries in our own words.
  insert into public.feature_options (kind, key, name, source, description)
  values
    ('fighting_style', 'archery', 'Archery', 'phb',
     '+2 to attack rolls with ranged weapons.'),
    ('fighting_style', 'defense', 'Defense', 'phb',
     '+1 to AC while you wear armor.'),
    ('fighting_style', 'dueling', 'Dueling', 'phb',
     '+2 to damage with a melee weapon held in one hand, when you hold no '
     'other weapon.'),
    ('fighting_style', 'great_weapon', 'Great Weapon Fighting', 'phb',
     'With a two-handed or versatile melee weapon held in both hands, reroll '
     'any 1 or 2 on a damage die once, keeping the new roll.'),
    ('fighting_style', 'protection', 'Protection', 'phb',
     'While holding a shield, use your reaction to give disadvantage to an '
     'attack against someone else within 5 feet of you.'),
    ('fighting_style', 'two_weapon', 'Two-Weapon Fighting', 'phb',
     'Add your ability modifier to the damage of your off-hand attack.'),
    ('fighting_style', 'blind_fighting', 'Blind Fighting', 'tcoe',
     'Blindsight out to 10 feet: you see what isn''t behind total cover, even '
     'blinded, in darkness, or against invisible creatures that haven''t '
     'hidden from you.'),
    ('fighting_style', 'interception', 'Interception', 'tcoe',
     'While holding a shield or a simple or martial weapon, use your reaction '
     'to cut the damage of a hit on someone within 5 feet of you by 1d10 + '
     'your proficiency bonus.'),
    ('fighting_style', 'superior_technique', 'Superior Technique', 'tcoe',
     'Learn one Battle Master maneuver and gain one d6 superiority die, '
     'regained on a short or long rest.'),
    ('fighting_style', 'thrown_weapon', 'Thrown Weapon Fighting', 'tcoe',
     'Draw a thrown weapon as part of the attack, and add +2 to damage when '
     'you hit by throwing one.'),
    ('fighting_style', 'unarmed', 'Unarmed Fighting', 'tcoe',
     'Unarmed strikes deal 1d6 + Strength, or 1d8 with no weapon or shield in '
     'hand, and you deal 1d4 to a creature you are grappling at the start of '
     'each of your turns.'),
    ('fighting_style', 'blessed_warrior', 'Blessed Warrior', 'tcoe',
     'Learn two cleric cantrips, cast with Charisma as paladin spells. Swap '
     'one for another when you gain a paladin level.'),
    ('fighting_style', 'druidic_warrior', 'Druidic Warrior', 'tcoe',
     'Learn two druid cantrips, cast with Wisdom as ranger spells. Swap one '
     'for another when you gain a ranger level.');

  -- 083's arrays become links. Every element is a domain value, so each one
  -- finds exactly one shared option.
  insert into public.class_feature_options (feature_id, option_id)
  select f.id, o.id
    from public.class_features f
   cross join lateral unnest(f.fighting_style_options) as s(key)
    join public.feature_options o
      on o.kind = 'fighting_style' and o.key = s.key::text
     and o.campaign_id is null
   where f.fighting_style_options is not null;

  -- Additional Fighting Style offers what the Fighter's own row offers.
  insert into public.class_feature_options (feature_id, option_id)
  select v_additional, l.option_id
    from public.class_feature_options l
   where l.feature_id = v_style;

  update public.class_features
     set description =
       'At 10th level, you choose a second option from the Fighting Style '
       'class feature.'
   where id = v_additional;
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'Rewrote % Additional Fighting Style rows (expected 1). Rolled back.', v_updated;
  end if;

  -- One pick per non-null style, on the class's base Fighting Style feature.
  insert into public.character_feature_choices
    (character_id, character_class_id, class_id, feature_id, option_id)
  select cc.character_id, cc.id, cc.class_id, f.id, o.id
    from public.character_classes cc
    join public.class_features f
      on f.class_id = cc.class_id and f.choice = 'fighting_style'
     and f.subclass_id is null
    join public.class_feature_options l on l.feature_id = f.id
    join public.feature_options o
      on o.id = l.option_id and o.key = cc.fighting_style::text
   where cc.fighting_style is not null;

  -- ---- Assert the end state, not the work. Do not demote to a notice. -----
  select count(*) into v_count
    from public.feature_options
   where kind = 'fighting_style' and campaign_id is null;
  if v_count <> c_expected_opts then
    raise exception '% shared fighting styles (expected %). Rolled back.',
      v_count, c_expected_opts;
  end if;

  -- Every array's keys are exactly its row's links, in both directions.
  select count(*) into v_count
    from public.class_features f
   where f.fighting_style_options is not null
     and (select array_agg(s::text order by s::text)
            from unnest(f.fighting_style_options) s)
         is distinct from
         (select array_agg(o.key order by o.key)
            from public.class_feature_options l
            join public.feature_options o on o.id = l.option_id
           where l.feature_id = f.id);
  if v_count <> 0 then
    raise exception '% feature rows whose links differ from their fighting_style_options. Rolled back.', v_count;
  end if;

  select count(*) into v_count
    from public.class_feature_options where feature_id = v_additional;
  select count(*) into v_expected
    from public.class_feature_options where feature_id = v_style;
  if v_count <> v_expected or v_count = 0 then
    raise exception '% links on Additional Fighting Style (expected %, the Fighter''s). Rolled back.',
      v_count, v_expected;
  end if;

  select count(*) into v_count
    from public.character_classes cc
   where cc.fighting_style is not null
     and not exists (
       select 1 from public.character_feature_choices ch
         join public.class_features f on f.id = ch.feature_id
         join public.feature_options o on o.id = ch.option_id
        where ch.character_class_id = cc.id
          and f.choice = 'fighting_style'
          and o.key = cc.fighting_style::text
     );
  if v_count <> 0 then
    raise exception
      '% class entries hold a fighting_style that has no pick after the backfill (a style outside its feature''s list?). Check: select id, class_id, fighting_style from character_classes where fighting_style is not null; Rolled back.',
      v_count;
  end if;
exception
  when no_data_found then
    raise exception 'Found no %. 055/071/080/082 seed it. Rolled back.', v_seeking;
  when too_many_rows then
    raise exception 'Found more than one %. Resolve the duplicate first. Rolled back.', v_seeking;
end
$$;

insert into public.schema_migrations (version) values ('095');

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
-- BLOCKS 2-5 make Nat's starting entry a level-10 Champion inside the block
-- (as the table owner), so they run whatever Nat's sheet holds today. They
-- need Nat to have a class entry in A; target_found = false means he has none.


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
  (select count(*) = 4 from pg_policies
    where schemaname = 'public' and tablename = 'character_feature_choices') as choice_policies,
  (select bool_and(relrowsecurity) from pg_class
    where oid in ('public.feature_options'::regclass,
                  'public.class_feature_options'::regclass,
                  'public.character_feature_choices'::regclass))             as rls_on,
  (select count(*) = 2 from pg_trigger
    where tgrelid = 'public.character_classes'::regclass
      and tgname in ('clear_stale_feature_choices', 'mirror_fighting_style')) as class_triggers,
  (select count(*) = 1 from pg_trigger
    where tgrelid = 'public.character_feature_choices'::regclass
      and tgname = 'pin_character_feature_choice_row')                       as pin_trigger,
  (select bool_and(not prosecdef) from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('clear_stale_feature_choices', 'mirror_fighting_style',
                      'pin_character_feature_choice_row'))                   as all_invoker,
  (select count(*) = 13 from public.feature_options
    where kind = 'fighting_style' and campaign_id is null)                   as thirteen_styles,
  (select count(*) = 36 from public.class_feature_options)                   as thirty_six_links,
  (select count(*) = 1 from public.schema_migrations
    where version = '095')                                                   as ledger_row;

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
-- BLOCK 2: owner, DM and a stranger each write a pick
-- ---------------------------------------------------------------------------
--
-- Through RLS, the way the client writes. A refused INSERT raises 42501, so
-- each is caught and reported. A refused UPDATE is a zero-row success, so the
-- stranger's update is read back instead.
--
-- CORRECT OUTPUT: seven rows.
--   target_found      true
--   owner_insert      ok            Archery on Fighting Style
--   dm_insert         ok            Defense on Additional Fighting Style
--   stranger_insert   refused
--   owner_update      dueling       Fighting Style changed by UPDATE
--   pinned_feature    true          an UPDATE moving the pick to another
--                                   feature changed option_id only
--   stranger_update   dueling       a stranger's UPDATE changed nothing

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

-- As the table owner: make the entry a level-10 Champion with no picks.
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
  c_player   constant uuid := '1313672b-6990-45a6-8a28-c448ca116d2d';
  c_dm       constant uuid := 'ea74d56b-8f45-4e4c-80f8-90a6d29b5adf';
  c_stranger constant uuid := '00000000-0000-0000-0000-000000000001';
  v_entry uuid := nullif(current_setting('verification.entry'), '')::uuid;
  v_char  uuid;
  v_class uuid;
  v_style uuid;
  v_add   uuid;
  v_pick  uuid;
  v_feat  uuid;
begin
  if v_entry is null then return; end if;

  perform set_config('request.jwt.claims',
    format('{"sub":"%s","role":"authenticated"}', c_player), true);
  select character_id, class_id into v_char, v_class
    from character_classes where id = v_entry;
  select id into v_style from class_features
   where class_id = v_class and name = 'Fighting Style' and campaign_id is null;
  select id into v_add from class_features
   where class_id = v_class and name = 'Additional Fighting Style' and campaign_id is null;

  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_style,
            (select id from feature_options where key = 'archery' and campaign_id is null))
    returning id into v_pick;
    perform set_config('verification.owner_insert', 'ok', true);
  exception when insufficient_privilege then
    perform set_config('verification.owner_insert', 'REFUSED -- should have passed', true);
  end;

  perform set_config('request.jwt.claims',
    format('{"sub":"%s","role":"authenticated"}', c_dm), true);
  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_add,
            (select id from feature_options where key = 'defense' and campaign_id is null));
    perform set_config('verification.dm_insert', 'ok', true);
  exception when insufficient_privilege then
    perform set_config('verification.dm_insert', 'REFUSED -- should have passed', true);
  end;

  perform set_config('request.jwt.claims',
    format('{"sub":"%s","role":"authenticated"}', c_stranger), true);
  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_add,
            (select id from feature_options where key = 'dueling' and campaign_id is null));
    perform set_config('verification.stranger_insert', 'ACCEPTED -- POLICY MISSING', true);
  exception when insufficient_privilege then
    perform set_config('verification.stranger_insert', 'refused', true);
  end;

  -- The owner changes Fighting Style to Dueling, by UPDATE.
  perform set_config('request.jwt.claims',
    format('{"sub":"%s","role":"authenticated"}', c_player), true);
  update character_feature_choices
     set option_id = (select id from feature_options where key = 'dueling' and campaign_id is null)
   where id = v_pick;
  perform set_config('verification.owner_update',
    (select o.key from character_feature_choices ch
       join feature_options o on o.id = ch.option_id where ch.id = v_pick), true);

  -- The owner tries to move that pick onto another feature row. The pin
  -- resets feature_id, so the row stays on Fighting Style.
  update character_feature_choices
     set feature_id = v_add
   where id = v_pick;
  select feature_id into v_feat from character_feature_choices where id = v_pick;
  perform set_config('verification.pinned_feature', (v_feat = v_style)::text, true);

  -- A stranger's update is filtered out by USING: zero rows, no error.
  perform set_config('request.jwt.claims',
    format('{"sub":"%s","role":"authenticated"}', c_stranger), true);
  update character_feature_choices
     set option_id = (select id from feature_options where key = 'protection' and campaign_id is null)
   where id = v_pick;
end
$$;

reset role;

select key as check, value as result
  from jsonb_each_text(jsonb_build_object(
         'target_found',    nullif(current_setting('verification.entry', true), '') is not null,
         'owner_insert',    current_setting('verification.owner_insert', true),
         'dm_insert',       current_setting('verification.dm_insert', true),
         'stranger_insert', current_setting('verification.stranger_insert', true),
         'owner_update',    current_setting('verification.owner_update', true),
         'pinned_feature',  current_setting('verification.pinned_feature', true),
         'stranger_update', (select o.key from public.character_feature_choices ch
                               join public.feature_options o on o.id = ch.option_id
                              where ch.character_class_id = nullif(current_setting('verification.entry'), '')::uuid
                                and o.key in ('dueling', 'protection'))
       ));

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 3: the constraints refuse each bad pick
-- ---------------------------------------------------------------------------
--
-- As the table owner: this is about the FKs and the unique constraints, not
-- RLS. Archery goes on Fighting Style first, then five bad inserts. The FK
-- cases use Defense, which isn't picked, so a unique constraint can't fire
-- first and mask a missing FK.
--
-- CORRECT OUTPUT: five rows, every result 'refused'.
--   same_option      Archery again, on Additional Fighting Style
--   second_pick      Defense, a second pick on Fighting Style
--   not_offered      a homebrew option the feature doesn't link
--   wrong_class      the Fighter's Additional Fighting Style, claiming Wizard
--   wrong_character  the entry's id with another character's id

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
    perform set_config('verification.same_option', 'skipped: Nat has no class entry', true);
    return;
  end if;

  select id into v_class  from classes where name = 'Fighter' and campaign_id is null;
  select id into v_wizard from classes where name = 'Wizard'  and campaign_id is null;
  update character_classes set class_id = v_class, subclass_id = null, fighting_style = null
   where id = v_entry;
  select id into v_style from class_features
   where class_id = v_class and name = 'Fighting Style' and campaign_id is null;
  select id into v_add from class_features
   where class_id = v_class and name = 'Additional Fighting Style' and campaign_id is null;
  select id into v_arch from feature_options where key = 'archery' and campaign_id is null;
  select id into v_def  from feature_options where key = 'defense' and campaign_id is null;

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
    perform set_config('verification.same_option', 'ACCEPTED -- UNIQUE MISSING', true);
  exception when unique_violation then
    perform set_config('verification.same_option', 'refused', true);
  end;

  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_style, v_def);
    perform set_config('verification.second_pick', 'ACCEPTED -- UNIQUE MISSING', true);
  exception when unique_violation then
    perform set_config('verification.second_pick', 'refused', true);
  end;

  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_class, v_add, v_fake);
    perform set_config('verification.not_offered', 'ACCEPTED -- FK MISSING', true);
  exception when foreign_key_violation then
    perform set_config('verification.not_offered', 'refused', true);
  end;

  begin
    insert into character_feature_choices
      (character_id, character_class_id, class_id, feature_id, option_id)
    values (v_char, v_entry, v_wizard, v_add, v_def);
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
         'same_option',     current_setting('verification.same_option', true),
         'second_pick',     current_setting('verification.second_pick', true),
         'not_offered',     current_setting('verification.not_offered', true),
         'wrong_class',     current_setting('verification.wrong_class', true),
         'wrong_character', current_setting('verification.wrong_character', true)
       ));

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 4: a subclass change clears subclass picks; a class change clears all
-- ---------------------------------------------------------------------------
--
-- As the table owner. Champion 10 with Archery (base feature) and Defense
-- (Champion feature), then a level drop, then the subclass is cleared, then
-- the class is changed.
--
-- CORRECT OUTPUT: target_found = true, before = 2, after_level = 2,
-- after_subclass = 1, after_class = 0.

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
  update character_classes set class_id = v_class, subclass_id = null, fighting_style = null
   where id = v_entry;
  update character_classes set subclass_id = v_champ, level = 10 where id = v_entry;

  insert into character_feature_choices
    (character_id, character_class_id, class_id, feature_id, option_id)
  select v_char, v_entry, v_class, f.id, o.id
    from class_features f, feature_options o
   where f.class_id = v_class and f.campaign_id is null and o.campaign_id is null
     and ((f.name = 'Fighting Style' and o.key = 'archery')
       or (f.name = 'Additional Fighting Style' and o.key = 'defense'));
  perform set_config('verification.before',
    (select count(*) from character_feature_choices where character_class_id = v_entry)::text, true);

  update character_classes set level = 3 where id = v_entry;
  perform set_config('verification.after_level',
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
         'after_level',    current_setting('verification.after_level', true),
         'after_subclass', current_setting('verification.after_subclass', true),
         'after_class',    current_setting('verification.after_class', true)
       ));

rollback;


-- ---------------------------------------------------------------------------
-- BLOCK 5: the old client's write is mirrored (until 096)
-- ---------------------------------------------------------------------------
--
-- As Nat, through RLS, the way the old client writes: set the column, change
-- it, clear it. A Champion pick on Additional Fighting Style sits alongside
-- throughout, and must survive every step: the mirror touches only the base
-- Fighting Style feature.
--
-- CORRECT OUTPUT: target_found = true, after_set = 'archery,defense',
-- after_change = 'defense,dueling', after_clear = 'defense'.

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
update public.character_classes
   set level = 10,
       subclass_id = (select s.id from public.subclasses s join public.classes k on k.id = s.class_id
                       where k.name = 'Fighter' and k.campaign_id is null and s.name = 'Champion')
 where id = nullif(current_setting('verification.entry'), '')::uuid;
insert into public.character_feature_choices
  (character_id, character_class_id, class_id, feature_id, option_id)
select cc.character_id, cc.id, cc.class_id, f.id, o.id
  from public.character_classes cc, public.class_features f, public.feature_options o
 where cc.id = nullif(current_setting('verification.entry'), '')::uuid
   and f.class_id = cc.class_id and f.name = 'Additional Fighting Style'
   and f.campaign_id is null
   and o.key = 'defense' and o.campaign_id is null;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"1313672b-6990-45a6-8a28-c448ca116d2d","role":"authenticated"}', true);

update public.character_classes set fighting_style = 'archery'
 where id = nullif(current_setting('verification.entry'), '')::uuid;
select set_config('verification.after_set', coalesce(string_agg(o.key, ',' order by o.key), ''), true)
  from public.character_feature_choices ch join public.feature_options o on o.id = ch.option_id
 where ch.character_class_id = nullif(current_setting('verification.entry'), '')::uuid;

update public.character_classes set fighting_style = 'dueling'
 where id = nullif(current_setting('verification.entry'), '')::uuid;
select set_config('verification.after_change', coalesce(string_agg(o.key, ',' order by o.key), ''), true)
  from public.character_feature_choices ch join public.feature_options o on o.id = ch.option_id
 where ch.character_class_id = nullif(current_setting('verification.entry'), '')::uuid;

update public.character_classes set fighting_style = null
 where id = nullif(current_setting('verification.entry'), '')::uuid;
select set_config('verification.after_clear', coalesce(string_agg(o.key, ',' order by o.key), ''), true)
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
