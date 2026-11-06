-- db/136_magic_items_xgte.sql
--
-- Xanathar's Guide to Everything's magic items: its chapter of common
-- trinkets, every one rarity 'common'. Seventh of eight seed files on 129's
-- columns; 130's header carries the reasoning for all eight.
--
-- These are the items most likely to actually turn up in Barovia's shops and
-- loot, which is why the book wrote them: cheap, flavourful, never a power
-- spike.
--
-- RUN AS ONE BLOCK. CORRECT OUTPUT: "Success. No rows returned."

begin;

create temp table _seed (
  name                text primary key,
  rarity              text not null,
  requires_attunement boolean not null,
  attunement_note     text,
  tags                text[] not null,
  description         text not null
) on commit drop;

insert into _seed values
($$Armor of Gleaming$$, 'common', false, null, array['armor','XGtE'],
 $$Any medium or heavy armour. It never gets dirty.$$),
($$Bead of Nourishment$$, 'common', false, null, array['wondrous item','consumable','XGtE'],
 $$A jelly bead that dissolves on the tongue and gives a full day's nourishment.$$),
($$Bead of Refreshment$$, 'common', false, null, array['wondrous item','consumable','XGtE'],
 $$Dropped into up to a pint of liquid, it dissolves and turns the liquid into fresh, cold drinking water. Poison and disease in it are not removed.$$),
($$Boots of False Tracks$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Only humanoids can wear these. You can choose to leave tracks like those of another kind of humanoid of your size.$$),
($$Candle of the Deep$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Its flame isn't put out by water. It sheds light like a normal candle and burns for 1 hour.$$),
($$Cast-Off Armor$$, 'common', false, null, array['armor','XGtE'],
 $$Any light, medium or heavy armour. You can doff it as an action.$$),
($$Charlatan's Die$$, 'common', true, null, array['wondrous item','XGtE'],
 $$Whenever you roll this six-sided die, you choose which number it shows.$$),
($$Cloak of Billowing$$, 'common', false, null, array['wondrous item','XGtE'],
 $$As a bonus action, make the cloak billow dramatically for the rest of your turn.$$),
($$Cloak of Many Fashions$$, 'common', false, null, array['wondrous item','XGtE'],
 $$As a bonus action, change the cloak's style, colour and apparent quality. Its weight stays the same, and it can't become anything other than a cloak.$$),
($$Clockwork Amulet$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Once per dawn, when you make an attack roll while wearing it, you can treat the d20 as a 10 instead of rolling.$$),
($$Clothes of Mending$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Elegant traveller's clothes that mend themselves of everyday wear and tear. Pieces that are destroyed stay destroyed.$$),
($$Dark Shard Amulet$$, 'common', true, $$by a warlock$$, array['wondrous item','XGtE'],
 $$A spellcasting focus for warlock spells. Once per long rest, try to cast a warlock cantrip you don't know (DC 10 Intelligence (Arcana) check); on a failure the action is wasted.$$),
($$Dread Helm$$, 'common', false, null, array['wondrous item','XGtE'],
 $$A fearsome steel helm that makes your eyes glow red while you wear it.$$),
($$Ear Horn of Hearing$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Held to your ear, it suppresses the deafened condition, letting you hear normally.$$),
($$Enduring Spellbook$$, 'common', false, null, array['wondrous item','XGtE'],
 $$A spellbook that can't be damaged by fire or immersion in water, and doesn't deteriorate with age.$$),
($$Ersatz Eye$$, 'common', true, null, array['wondrous item','XGtE'],
 $$An artificial eye that replaces a real one, letting you see normally. Can't be removed against your will, and you can take it out or put it in as an action.$$),
($$Hat of Vermin$$, 'common', false, null, array['wondrous item','XGtE'],
 $$3 charges. Spend one to pull a bat, frog or rat from the hat. It is real, unfriendly, and vanishes after an hour. Regains all charges at dawn.$$),
($$Hat of Wizardry$$, 'common', true, $$by a wizard$$, array['wondrous item','XGtE'],
 $$A spellcasting focus for wizard spells. Once per long rest, try to cast a wizard cantrip you don't know (DC 10 Intelligence (Arcana) check).$$),
($$Heward's Handy Spice Pouch$$, 'common', false, null, array['wondrous item','XGtE'],
 $$10 charges. Spend one to pull out a pinch of any nonmagical spice you name. Regains 1d6+4 at dawn.$$),
($$Horn of Silent Alarm$$, 'common', false, null, array['wondrous item','XGtE'],
 $$4 charges. Blowing it spends one, and only the creature you choose within 600 feet hears it. Regains 1d4 at dawn.$$),
($$Instrument of Illusions$$, 'common', true, null, array['wondrous item','XGtE'],
 $$While you play it, you can create harmless illusory visual effects in a 15-foot-radius sphere around it, themed to your music.$$),
($$Instrument of Scribing$$, 'common', true, null, array['wondrous item','XGtE'],
 $$3 charges. While playing, write a magical message of up to six words on an object or surface within 30 feet, lasting until dispelled or rewritten. Regains all charges at dawn.$$),
($$Lock of Trickery$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Looks like an ordinary lock and comes with one key. Picking it with thieves' tools is at disadvantage.$$),
($$Moon-Touched Sword$$, 'common', false, null, array['weapon','XGtE'],
 $$Any sword. In darkness, the unsheathed blade sheds moonlight: bright light in a 15-foot radius and dim for 15 more.$$),
($$Mystery Key$$, 'common', false, null, array['wondrous item','XGtE'],
 $$A question mark is worked into its head. It has a 5% chance of unlocking any lock it is inserted into, and vanishes once it does.$$),
($$Orb of Direction$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Hold it and use an action to learn which way is magnetic north. Useless where there is no north.$$),
($$Orb of Time$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Hold it and use an action to learn whether it is morning, afternoon, evening or night outside. Useless where those don't apply.$$),
($$Perfume of Bewitching$$, 'common', false, null, array['wondrous item','consumable','XGtE'],
 $$Applied as an action, it gives advantage on Charisma checks directed at humanoids of CR 1 or lower for 1 hour. One use.$$),
($$Pipe of Smoke Monsters$$, 'common', false, null, array['wondrous item','XGtE'],
 $$While smoking it, you can exhale a puff of smoke shaped like a single creature, such as a dragon or a flumph.$$),
($$Pole of Angling$$, 'common', false, null, array['wondrous item','XGtE'],
 $$A 10-foot pole that becomes a fishing pole with hook, line and reel on its command word, and back again.$$),
($$Pole of Collapsing$$, 'common', false, null, array['wondrous item','XGtE'],
 $$A 10-foot pole that collapses into a 1-foot rod on its command word, and extends again.$$),
($$Pot of Awakening$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Plant an ordinary shrub in it and after 30 days the shrub becomes an awakened shrub, friendly to you.$$),
($$Rope of Mending$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Cut into pieces, then hold the ends together and speak its command word, and the pieces knit back into 50 feet of rope.$$),
($$Ruby of the War Mage$$, 'common', true, $$by a spellcaster$$, array['wondrous item','XGtE'],
 $$Pressed against a simple or martial weapon for 10 minutes, it fuses to it, and you can then use that weapon as a spellcasting focus.$$),
($$Shield of Expression$$, 'common', false, null, array['armor','XGtE'],
 $$A shield bearing a face. As a bonus action, change the face's expression.$$),
($$Smoldering Armor$$, 'common', false, null, array['armor','XGtE'],
 $$Any armour. Wisps of harmless, odourless smoke rise from it while it is worn.$$),
($$Staff of Adornment$$, 'common', false, null, array['staff','XGtE'],
 $$Set an object under a pound on its tip and it floats there; up to three objects can orbit it at once.$$),
($$Staff of Birdcalls$$, 'common', false, null, array['staff','XGtE'],
 $$10 charges. Spend one to make a birdcall of your choice audible out to 60 feet. Regains 1d6+4 at dawn.$$),
($$Staff of Flowers$$, 'common', false, null, array['staff','XGtE'],
 $$10 charges. Spend one to make a flower of your choice sprout from nearby earth or the staff's tip. Regains 1d6+4 at dawn.$$),
($$Talking Doll$$, 'common', true, null, array['wondrous item','XGtE'],
 $$After a short rest, record up to six phrases into it and set the circumstance that triggers each; it speaks them aloud when the condition is met.$$),
($$Tankard of Sobriety$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Drinking ale, wine or any alcohol from it never gets you inebriated. It doesn't protect against poison in the drink.$$),
($$Unbreakable Arrow$$, 'common', false, null, array['weapon','XGtE'],
 $$An arrow that can't be broken, except within an antimagic field.$$),
($$Veteran's Cane$$, 'common', false, null, array['wondrous item','XGtE'],
 $$Speak its command word as a bonus action and it becomes an ordinary longsword. It doesn't turn back.$$),
($$Walloping Ammunition$$, 'common', false, null, array['weapon','consumable','XGtE'],
 $$A creature hit by this ammunition makes a DC 10 Strength save or is knocked prone.$$),
($$Wand of Conducting$$, 'common', false, null, array['wand','XGtE'],
 $$3 charges. Wave it to fill the air with orchestral music for up to 1 minute. Regains all charges at dawn; a 1 in 20 chance it plays a sad tuba sound and crumbles when emptied.$$),
($$Wand of Pyrotechnics$$, 'common', false, null, array['wand','XGtE'],
 $$7 charges. Spend one to burst a harmless, loud and colourful explosion of light at a point within 60 feet. Regains 1d6+1 at dawn.$$),
($$Wand of Scowls$$, 'common', false, null, array['wand','XGtE'],
 $$3 charges. Spend one to make a humanoid within 30 feet scowl for a minute (DC 10 Charisma). Regains all charges at dawn.$$),
($$Wand of Smiles$$, 'common', false, null, array['wand','XGtE'],
 $$3 charges. Spend one to make a humanoid within 30 feet smile for a minute (DC 10 Charisma). Regains all charges at dawn.$$);

insert into public.items
  (name, description, price_cp, tags, kind,
   rarity, requires_attunement, attunement_note)
select s.name, s.description, 0, s.tags, 'general',
       s.rarity, s.requires_attunement, s.attunement_note
  from _seed s
 where not exists (
   select 1 from public.items i
    where i.campaign_id is null and i.name = s.name
 );

do $do$
declare
  v_expected int := (select count(*) from _seed);
  v_found    int;
begin
  select count(*) into v_found
    from _seed s
    join public.items i
      on i.campaign_id is null
     and i.name = s.name
     and i.rarity = s.rarity
     and i.requires_attunement = s.requires_attunement;
  if v_found <> v_expected then
    raise exception 'magic item seed incomplete: % of % rows present', v_found, v_expected;
  end if;
end
$do$;

insert into public.schema_migrations (version) values ('136');

commit;
