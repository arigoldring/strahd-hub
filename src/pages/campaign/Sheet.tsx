import { KeyboardEvent, useEffect, useRef, useState } from "react";
import { useCampaign } from "../../components/CampaignLayout";
import { useAuth } from "../../services/AuthContext";
import { useCharacter } from "../../hooks/useCharacter";
import { useParty } from "../../hooks/useParty";
import { useCharacterInventory } from "../../hooks/useCharacterInventory";
import { useCharacterFeats } from "../../hooks/useCharacterFeats";
import { useCharacterSheet, type FeaturePickWrite } from "../../hooks/useCharacterSheet";
import { useClasses } from "../../hooks/useClasses";
import { useRaces } from "../../hooks/useRaces";
import { useSubclasses } from "../../hooks/useSubclasses";
import { useClassFeatures } from "../../hooks/useClassFeatures";
import { useFeatureOptions } from "../../hooks/useFeatureOptions";
import {
  ABILITIES,
  ABILITY_LABELS,
  SKILLS,
  abilityModifier,
  armorClass,
  attacksPerAction,
  averageHp,
  battleReadyAbility,
  collectEffects,
  critThreshold,
  damageString,
  formatModifier,
  hpBonus,
  initiative,
  martialArtsDie,
  martialArtsWeapon,
  picksAllowed,
  ordinal,
  pactSlots,
  proficiencyBonus,
  resourceMax,
  resourceRecharge,
  saveAura,
  skillBonus,
  sneakAttackDice,
  speedBonus,
  spellSlots,
  styleAttackBonus,
  totalLevel,
  untrainedCheckBonus,
  weaponAbility,
  weaponTraining,
  type Ability,
  type EffectLevels,
  type FightingStyleKey,
  type ProficiencyLevel,
  type SkillKey,
} from "../../data/rules";
import {
  saveSet,
  skillLevels,
  type CharacterClassEntry,
  type CharacterStats,
  type CharacterStatsPatch,
  type FeaturePick,
  type Proficiency,
} from "../../services/characterSheet";
import {
  FEATURE_OPTION_KIND_LABELS,
  SUBCLASS_SOURCE_LABELS,
  type CharacterClass,
  type ClassFeature,
  type FeatureOption,
} from "../../services/classes";
import type { Character as CharacterModel } from "../../services/characters";
import type { CharacterInventoryEntry } from "../../services/characterInventory";
import type { Armor, Weapon } from "../../services/items";
import { errorMessage } from "../../lib/errors";
import {
  Band,
  CharacterCarried,
  CharacterFeats,
  CharacterPurse,
  CharacterSpells,
} from "./Character";
import { SheetResources, type SheetCounter } from "./SheetResources";
import { featureResourceKey } from "../../services/characterResources";
import "./character.css";
import "./sheet.css";

/**
 * The full character sheet: abilities, saves, skills, combat numbers and
 * attacks, beside the real spells, feats, gear and purse sections reused from
 * the Character page.
 *
 * Every number lives in the database (054-057) and is edited by the owner or
 * the campaign's DM, the same can_edit_character line spells and gear use.
 * Only inputs are stored; everything derived (modifiers, AC, attacks, spell
 * DC) is computed here from src/data/rules.ts.
 *
 * A DM has no PC of their own, so they get a picker over the party instead of
 * the create flow.
 */
export function Sheet() {
  const campaign = useCampaign();
  return (
    <div className="ch sm-wide">
      {campaign.isDm ? <DmSheetPicker /> : <OwnSheet />}
    </div>
  );
}

function OwnSheet() {
  const campaign = useCampaign();
  const { data: character, isLoading, error } = useCharacter(campaign.id);

  if (isLoading) return <p>Consulting the ledger...</p>;
  if (error) return <p>Couldn't load your character: {error.message}</p>;
  if (!character) {
    return (
      <p className="ch-empty">Create a character on the Character page first.</p>
    );
  }
  return <FullSheet key={character.id} character={character} isOwn />;
}

function DmSheetPicker() {
  const campaign = useCampaign();
  const { profile } = useAuth();
  const { data: party = [], isLoading, error } = useParty(campaign.id);
  const [pickedId, setPickedId] = useState<string | null>(null);

  if (isLoading) return <p>Consulting the ledger...</p>;
  if (error) return <p>{error.message}</p>;
  if (party.length === 0) {
    return <p className="ch-empty">No characters in this campaign yet.</p>;
  }

  const character = party.find((c) => c.id === pickedId) ?? party[0];

  return (
    <>
      <label className="sm-picker">
        <span>Viewing</span>
        <select
          value={character.id}
          onChange={(e) => setPickedId(e.target.value)}
        >
          {party.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
              {c.playerName ? ` (${c.playerName})` : ""}
            </option>
          ))}
        </select>
      </label>
      {/* Keyed so switching character remounts the sheet and its fields'
          local drafts start from the new character's values. */}
      <FullSheet
        key={character.id}
        character={character}
        isOwn={character.userId === profile?.id}
      />
    </>
  );
}

type ArmorEntry = CharacterInventoryEntry & Armor;
type WeaponEntry = CharacterInventoryEntry & Weapon;

function FullSheet({
  character,
  isOwn,
}: {
  character: CharacterModel;
  isOwn: boolean;
}) {
  const campaign = useCampaign();
  // 056's policies are owner-or-DM; this mirrors them so a player browsing
  // someone else's sheet sees numbers, not inputs that would be refused.
  const canEdit = isOwn || campaign.isDm;

  const sheetQuery = useCharacterSheet(character.id);
  const { data: classCatalog = [] } = useClasses(campaign.id);
  const { data: subclassCatalog = [] } = useSubclasses(campaign.id);
  const { data: featureCatalog = [] } = useClassFeatures(campaign.id);
  const { data: featureOptions = [] } = useFeatureOptions(campaign.id);
  const { data: races = [] } = useRaces(campaign.id);
  // Same key as the Carried section below, so this is a cache hit.
  const { data: gear = [], setEquipped } = useCharacterInventory(character.id);
  // Same key as the Feats section below, so this is a cache hit too. Read
  // here for the feats' use counters.
  const { data: ownFeats = [] } = useCharacterFeats(character.id);

  // One error line under the header for any failed save. Each control could
  // own its own, but on a sheet of ~40 inputs one shared line is easier to
  // notice and the message says what failed.
  const [saveError, setSaveError] = useState<string | null>(null);
  const run = (action: Promise<unknown>, what: string) => {
    setSaveError(null);
    action.catch((err) => setSaveError(errorMessage(err, `Couldn't save ${what}`)));
  };

  if (sheetQuery.isLoading) return <p>Consulting the ledger...</p>;
  if (sheetQuery.error || !sheetQuery.data) {
    return <p className="ch-error">{sheetQuery.error?.message ?? "No sheet."}</p>;
  }

  const { stats, classes, proficiencies, picks } = sheetQuery.data;
  const updateStats = (patch: CharacterStatsPatch, what: string) =>
    run(sheetQuery.updateStats(patch), what);

  // ---- derived, every render ----
  const startingEntry = classes.find((c) => c.isStarting) ?? classes[0];
  const cls = classCatalog.find((c) => c.id === startingEntry?.classId) ?? null;
  const classSubclasses = subclassCatalog.filter(
    (s) => s.classId === startingEntry?.classId,
  );
  const subclass =
    classSubclasses.find((s) => s.id === startingEntry?.subclassId) ?? null;
  // Opens at the class's own level, not the total (a multiclass Fighter 2 /
  // Wizard 2 has no archetype yet). A subclass already chosen stays editable
  // below that level, so one kept after a level drop can still be cleared.
  const subclassReached =
    !!startingEntry && !!cls && startingEntry.level >= cls.subclassLevel;
  const canPickSubclass =
    canEdit &&
    classSubclasses.length > 0 &&
    (subclassReached || startingEntry?.subclassId != null);
  const subclassHint = !cls
    ? "Pick a class first"
    : classSubclasses.length > 0 && !subclassReached && !subclass
      ? `Chosen at level ${cls.subclassLevel}`
      : undefined;
  const race = races.find((r) => r.id === stats.raceId) ?? null;
  const level = totalLevel(classes);
  const pb = proficiencyBonus(level);
  const mod = (a: Ability) => abilityModifier(stats.scores[a]);
  const saves = saveSet(proficiencies);
  const skills = skillLevels(proficiencies);
  // Every class feature effect the character has (121), from every class
  // entry, each with the level of the class that grants it. The numbers
  // below read from this; a feature with no effect key is display only.
  const effects = collectEffects(classes, featureCatalog);
  // Untrained skills take Jack of All Trades or Remarkable Athlete, and so
  // do the passives, which are built from this.
  const skillTotal = (key: SkillKey) => {
    const skill = SKILLS.find((s) => s.key === key)!;
    const prof = skills[key];
    const untrained = prof === 0 ? untrainedCheckBonus(skill.ability, pb, effects).bonus : 0;
    return skillBonus(mod(skill.ability), pb, prof) + untrained;
  };
  const mods = Object.fromEntries(ABILITIES.map((a) => [a, mod(a)])) as Record<Ability, number>;
  const init = initiative(mods, pb, effects);
  const aura = saveAura(mod("cha"), effects);
  // Use counters (153) from the starting class's features up to its level,
  // the Class Features list's own rule. The maximum is derived here every
  // render, so a level-up or a new score changes it at once. A counter at 0
  // (before its first step) isn't shown.
  const classLevel = startingEntry?.level ?? 0;
  const counters: SheetCounter[] = startingEntry
    ? featureCatalog
        .filter(
          (f) =>
            f.classId === startingEntry.classId &&
            f.level <= classLevel &&
            (f.subclassId == null || f.subclassId === startingEntry.subclassId),
        )
        .flatMap((f) =>
          f.resources.map((r) => ({
            key: featureResourceKey(r.id),
            name: r.name,
            source: f.name,
            max: resourceMax(r, { level: classLevel, pb, mods }),
            recharge: resourceRecharge(r, classLevel),
          })),
        )
        .filter((c) => c.max > 0)
    : [];
  // Spell slots (158), ahead of the feature counters: the class's slot table,
  // else the subclass's (Eldritch Knight, Arcane Trickster). Starting class
  // only, like everything above.
  const casterType = cls?.casterType ?? subclass?.casterType ?? null;
  const slotCounters: SheetCounter[] = spellSlots(casterType, classLevel).map((max, i) => ({
    key: `slot:${i + 1}`,
    name: `${ordinal(i + 1)}-level slots`,
    source: "Spell Slots",
    max,
    recharge: "long",
  }));
  const pact = casterType === "pact" ? pactSlots(classLevel) : null;
  if (pact) {
    slotCounters.push({
      key: "pact",
      name: `Pact slots (${ordinal(pact.slotLevel)} level)`,
      source: "Pact Magic",
      max: pact.count,
      recharge: "short",
    });
  }
  counters.unshift(...slotCounters);
  // Feats' counters (157) read the character's total level, not a class's.
  for (const feat of ownFeats) {
    for (const r of feat.resources) {
      const max = resourceMax(r, { level, pb, mods });
      if (max > 0) {
        counters.push({
          key: featureResourceKey(r.id),
          name: r.name,
          source: feat.name,
          max,
          recharge: resourceRecharge(r, level),
        });
      }
    }
  }
  // Eldritch Knight and Arcane Trickster cast through a class that doesn't.
  const spellAbility = cls?.spellAbility ?? subclass?.spellAbility ?? null;

  // Every fighting style the character holds: all of their picks (095),
  // across every class entry and every feature, so a Champion's second style
  // and a Fighter/Paladin multiclass both count. rules.ts tests membership,
  // so a key held twice would count once. A homebrew style has no key and no
  // automatic effect.
  const styles: FightingStyleKey[] = picks.flatMap((p) => {
    const o = featureOptions.find((x) => x.id === p.optionId);
    return o?.kind === "fighting_style" && o.key ? [o.key] : [];
  });

  const armors = gear.filter((i): i is ArmorEntry => i.kind === "armor");
  const weapons = gear.filter((i): i is WeaponEntry => i.kind === "weapon");
  const armor = armors.find((a) => a.equipped && a.category !== "shield") ?? null;
  const shield = armors.find((a) => a.equipped && a.category === "shield") ?? null;
  const ac = armorClass({
    armor,
    shield,
    dexMod: mod("dex"),
    unarmored: cls?.unarmoredAbility
      ? {
          ability: cls.unarmoredAbility,
          mod: mod(cls.unarmoredAbility),
          // The Monk loses Unarmored Defense with a shield; the Barbarian
          // doesn't. Not a column on classes, so it's named here.
          allowsShield: cls.name !== "Monk",
        }
      : null,
    styles,
    bonus: stats.acBonus,
    natural: effects.has("draconic_resilience")
      ? { name: "Draconic Resilience", base: 13 }
      : null,
  });

  // Equip one of a kind (body armour, or shield) and un-equip the rest of
  // that kind, so at most one of each is worn (057 leaves this to the client).
  const equip = (pool: ArmorEntry[], entryId: string) => {
    const writes = pool
      .filter((a) => a.equipped !== (a.entryId === entryId))
      .map((a) => setEquipped({ entryId: a.entryId, equipped: a.entryId === entryId }));
    run(Promise.all(writes), "armour");
  };

  return (
    <article className="ch-sheet">
      <header className="ch-head">
        <p className="ch-eyebrow">— Full Sheet —</p>
        <div className="ch-identity">
          <h1 className="ch-name">{character.name}</h1>
        </div>
        <div className="sm-classline">
          <label>
            <span>Race</span>
            <select
              value={stats.raceId ?? ""}
              disabled={!canEdit}
              // A new race resets the speed override, so speed follows the
              // race again until someone types a different number.
              onChange={(e) =>
                updateStats(
                  { raceId: e.target.value || null, speedOverride: null },
                  "race",
                )
              }
            >
              <option value="">Choose a race...</option>
              {races.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            <span>Class</span>
            <select
              value={cls?.id ?? ""}
              disabled={!canEdit}
              onChange={(e) => {
                const picked = classCatalog.find((c) => c.id === e.target.value);
                if (!picked) return;
                // Replaces the save proficiencies with the class's two; they
                // stay toggleable afterwards (Resilient, multiclass).
                run(
                  sheetQuery.setClass({
                    existing: startingEntry,
                    classId: picked.id,
                    saves: picked.saves,
                  }),
                  "class",
                );
              }}
            >
              {!cls && <option value="">Choose a class...</option>}
              {classCatalog.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            <span>Level</span>
            <NumberField
              value={startingEntry?.level ?? 1}
              min={1}
              max={20}
              disabled={!canEdit || !startingEntry}
              title={startingEntry ? undefined : "Pick a class first"}
              onCommit={(n) =>
                startingEntry &&
                run(sheetQuery.setLevel({ entryId: startingEntry.id, level: n }), "level")
              }
            />
          </label>
          <label>
            <span>{cls?.subclassTitle ?? "Subclass"}</span>
            <select
              className="sm-classline__wide"
              value={startingEntry?.subclassId ?? ""}
              disabled={!canPickSubclass}
              title={subclassHint}
              onChange={(e) =>
                startingEntry &&
                run(
                  sheetQuery.setSubclass({
                    entryId: startingEntry.id,
                    subclassId: e.target.value || null,
                  }),
                  "subclass",
                )
              }
            >
              <option value="">
                {cls && classSubclasses.length === 0 ? "None available" : "None"}
              </option>
              {classSubclasses.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                  {s.source ? ` (${SUBCLASS_SOURCE_LABELS[s.source]})` : " (Homebrew)"}
                </option>
              ))}
            </select>
          </label>
        </div>
        {saveError && <p className="ch-error sm-save-error">{saveError}</p>}
      </header>

      <CombatBlock
        stats={stats}
        canEdit={canEdit}
        updateStats={updateStats}
        adjustHp={(delta) => run(sheetQuery.adjustHp(delta), "HP")}
        cls={cls}
        level={level}
        conMod={mod("con")}
        raceSpeed={race?.speed ?? null}
        ac={ac}
        armor={armor}
        shield={shield}
        armors={armors}
        equip={equip}
        featureSpeed={speedBonus(effects, {
          armorCategory: armor?.category ?? null,
          shield: shield != null,
        })}
        featureHp={hpBonus(effects)}
      />

      <div className="sm-derived">
        <Stat label="Proficiency" value={formatModifier(pb)} />
        <Stat
          label="Initiative"
          value={formatModifier(init.total)}
          title={init.parts.join(" · ")}
        />
        <Stat label="Passive Perception" value={String(10 + skillTotal("perception"))} />
        <Stat
          label="Passive Investigation"
          value={String(10 + skillTotal("investigation"))}
        />
        <Stat label="Passive Insight" value={String(10 + skillTotal("insight"))} />
        <Stat
          label={spellAbility ? `Spell Save DC (${spellAbility.toUpperCase()})` : "Spell Save DC"}
          value={spellAbility ? String(8 + pb + mod(spellAbility)) : "—"}
        />
        <Stat
          label="Spell Attack"
          value={spellAbility ? formatModifier(pb + mod(spellAbility)) : "—"}
        />
      </div>

      <SheetResources characterId={character.id} counters={counters} canEdit={canEdit} />

      {/* Two columns on a wide screen: the numbers on the left, the lists on
          the right. Each column is a plain stack of bands, so collapsing to
          one column on a narrow screen is a CSS change, not a markup one. */}
      <div className="sm-layout">
        <div className="sm-layout__col sm-layout__col--stats">
          <Band label="Abilities" />
          <div className="ch-body">
            <div className="sm-abilities">
              {ABILITIES.map((a) => (
                <label key={a} className="sm-ability">
                  <span className="sm-ability__label">{ABILITY_LABELS[a]}</span>
                  <span className="sm-ability__mod">{formatModifier(mod(a))}</span>
                  <NumberField
                    className="sm-ability__score"
                    value={stats.scores[a]}
                    min={1}
                    max={30}
                    disabled={!canEdit}
                    onCommit={(n) =>
                      updateStats({ scores: { [a]: n } }, ABILITY_LABELS[a])
                    }
                  />
                </label>
              ))}
            </div>
          </div>

          <section>
            <Band label="Saving Throws" />
            <div className="ch-body">
              <ul className="sm-list sm-list--saves">
                {ABILITIES.map((a) => (
                  <li key={a}>
                    <label className="sm-row">
                      <input
                        type="checkbox"
                        checked={saves.has(a)}
                        disabled={!canEdit}
                        onChange={(e) =>
                          run(
                            sheetQuery.setProficiency({
                              kind: "save",
                              key: a,
                              level: e.target.checked ? 1 : 0,
                            }),
                            "saving throw",
                          )
                        }
                      />
                      <span className="sm-row__name">{ABILITY_LABELS[a]}</span>
                      <span
                        className="sm-row__total"
                        title={aura ? `Includes Aura of Protection ${formatModifier(aura)}` : undefined}
                      >
                        {formatModifier(mod(a) + (saves.has(a) ? pb : 0) + aura)}
                      </span>
                    </label>
                  </li>
                ))}
              </ul>
            </div>
          </section>

          <section>
            <Band label="Skills" />
            <div className="ch-body">
              <ul className="sm-list">
                {SKILLS.map((s) => {
                  const prof = skills[s.key];
                  return (
                    <li key={s.key} className="sm-row">
                      <button
                        type="button"
                        className={`sm-pip sm-pip--${prof}`}
                        title={PROF_LABELS[prof]}
                        aria-label={`${s.label}: ${PROF_LABELS[prof]}`}
                        disabled={!canEdit}
                        onClick={() =>
                          run(
                            sheetQuery.setProficiency({
                              kind: "skill",
                              key: s.key,
                              level: ((prof + 1) % 3) as ProficiencyLevel,
                            }),
                            s.label,
                          )
                        }
                      />
                      <span className="sm-row__name">
                        {s.label}
                        <span className="sm-row__ability">{s.ability}</span>
                        {s.key === "stealth" && armor?.stealthDisadvantage && (
                          <span
                            className="sm-row__flag"
                            title={`${armor.name} imposes disadvantage`}
                          >
                            disadv.
                          </span>
                        )}
                      </span>
                      <span className="sm-row__total">
                        {formatModifier(skillTotal(s.key))}
                      </span>
                    </li>
                  );
                })}
              </ul>
              <p className="sm-legend">
                Tap a pip: ○ untrained · ● proficient · ◎ expertise
              </p>
            </div>
          </section>
        </div>

        <div className="sm-layout__col">
          <AttacksBlock
            weapons={weapons}
            proficiencies={proficiencies}
            canEdit={canEdit}
            toggleProf={(itemId, proficient) =>
              run(
                sheetQuery.setProficiency({
                  kind: "weapon",
                  key: itemId,
                  level: proficient ? 1 : 0,
                }),
                "weapon proficiency",
              )
            }
            cls={cls}
            pb={pb}
            strMod={mod("str")}
            dexMod={mod("dex")}
            intMod={mod("int")}
            styles={styles}
            effects={effects}
            unarmored={armor == null && shield == null}
          />
          <CharacterSpells characterId={character.id} isOwn={isOwn} />
          <CharacterFeats characterId={character.id} isOwn={isOwn} />
          <CharacterCarried characterId={character.id} isOwn={isOwn} />
          <CharacterPurse character={character} />

          <Band label="Class Features" />
          <div className="ch-body">
            {subclass && cls && (
              <p className="sm-subclass">
                <span className="sm-subclass__name">
                  {cls.subclassTitle}: {subclass.name}
                </span>{" "}
                {subclass.description}
              </p>
            )}
            <ClassFeatures
              entry={startingEntry}
              catalog={featureCatalog}
              options={featureOptions}
              picks={picks}
              canEdit={canEdit}
              writePick={(write) => run(sheetQuery.writeFeaturePick(write), "your choice")}
            />
          </div>
        </div>
      </div>
    </article>
  );
}

/**
 * AC, HP, speed and hit dice: the numbers read most often mid-fight, full
 * width under the name. AC is derived from the armour equipped out of the
 * real inventory (057); HP goes through adjust_character_hp for damage and
 * healing so two people hitting the same character can't lose an update.
 */
function CombatBlock({
  stats,
  canEdit,
  updateStats,
  adjustHp,
  cls,
  level,
  conMod,
  raceSpeed,
  ac,
  armor,
  shield,
  armors,
  equip,
  featureSpeed,
  featureHp,
}: {
  stats: CharacterStats;
  canEdit: boolean;
  updateStats: (patch: CharacterStatsPatch, what: string) => void;
  adjustHp: (delta: number) => void;
  cls: CharacterClass | null;
  level: number;
  conMod: number;
  raceSpeed: number | null;
  ac: { total: number; parts: string[] };
  armor: ArmorEntry | null;
  shield: ArmorEntry | null;
  armors: ArmorEntry[];
  equip: (pool: ArmorEntry[], entryId: string) => void;
  /** Speed from class features (121), already checked against what's worn. */
  featureSpeed: { bonus: number; parts: string[] };
  /** Max HP class features add (Draconic Resilience), for the average hint. */
  featureHp: number;
}) {
  const bodyArmors = armors.filter((a) => a.category !== "shield");
  const shields = armors.filter((a) => a.category === "shield");
  const [hpDelta, setHpDelta] = useState("");

  const baseSpeed = stats.speedOverride ?? raceSpeed ?? 30;
  // Heavy armour without the Strength for it costs 10 ft of speed (PHB).
  const tooHeavy =
    armor?.strengthRequirement != null &&
    stats.scores.str < armor.strengthRequirement;
  const speed = Math.max(0, baseSpeed - (tooHeavy ? 10 : 0) + featureSpeed.bonus);

  const applyHp = (sign: 1 | -1) => {
    const n = Number.parseInt(hpDelta, 10);
    if (!Number.isNaN(n) && n > 0) {
      adjustHp(sign * n);
      setHpDelta("");
    }
  };

  return (
    <div className="sm-combat">
      <div className="sm-combat__tile">
        <span className="sm-stat__label">Armor Class</span>
        <span className="sm-combat__big">{ac.total}</span>
        <span className="sm-combat__note">{ac.parts.join(" · ")}</span>
        <div className="sm-combat__controls">
          <select
            aria-label="Armor worn"
            value={armor?.entryId ?? ""}
            disabled={!canEdit}
            onChange={(e) => equip(bodyArmors, e.target.value)}
          >
            <option value="">No armor</option>
            {bodyArmors.map((a) => (
              <option key={a.entryId} value={a.entryId}>
                {a.name} ({a.category})
              </option>
            ))}
          </select>
          {shields.length > 0 && (
            <select
              aria-label="Shield"
              value={shield?.entryId ?? ""}
              disabled={!canEdit}
              onChange={(e) => equip(shields, e.target.value)}
            >
              <option value="">No shield</option>
              {shields.map((a) => (
                <option key={a.entryId} value={a.entryId}>
                  {a.name}
                </option>
              ))}
            </select>
          )}
          <label className="sm-combat__inline">
            <span>Other</span>
            <NumberField
              value={stats.acBonus}
              min={-10}
              max={20}
              disabled={!canEdit}
              onCommit={(n) => updateStats({ acBonus: n }, "AC bonus")}
            />
          </label>
        </div>
        {bodyArmors.length === 0 && (
          <span className="sm-combat__note">No armor in inventory.</span>
        )}
      </div>

      <div className="sm-combat__tile">
        <span className="sm-stat__label">Hit Points</span>
        <div className="sm-hp">
          <NumberField
            className="sm-hp__current"
            aria-label="Current HP"
            value={stats.hpCurrent}
            min={0}
            max={999}
            disabled={!canEdit}
            onCommit={(n) => updateStats({ hpCurrent: n }, "HP")}
          />
          <span className="sm-hp__slash">/</span>
          <NumberField
            aria-label="Max HP"
            value={stats.hpMax}
            min={1}
            max={999}
            disabled={!canEdit}
            onCommit={(n) => updateStats({ hpMax: n }, "max HP")}
          />
        </div>
        <label className="sm-combat__inline">
          <span>Temp</span>
          <NumberField
            value={stats.hpTemp}
            min={0}
            max={999}
            disabled={!canEdit}
            onCommit={(n) => updateStats({ hpTemp: n }, "temp HP")}
          />
        </label>
        {canEdit && (
          <div className="sm-hp__adjust">
            <input
              type="number"
              min={1}
              aria-label="Damage or healing amount"
              placeholder="amt"
              value={hpDelta}
              onChange={(e) => setHpDelta(e.target.value)}
            />
            <button type="button" className="ch-button ch-button--danger" onClick={() => applyHp(-1)}>
              Damage
            </button>
            <button type="button" className="ch-button" onClick={() => applyHp(1)}>
              Heal
            </button>
          </div>
        )}
        {cls && (
          <span className="sm-combat__note">
            Average for level {level}: {averageHp(cls.hitDie, level, conMod) + featureHp}
            {featureHp > 0 && ` (incl. Draconic Resilience +${featureHp})`}
          </span>
        )}
      </div>

      <div className="sm-combat__tile">
        <span className="sm-stat__label">Speed</span>
        <span className="sm-combat__big">
          {speed}
          <small> ft</small>
        </span>
        <label className="sm-combat__inline">
          <span>Base</span>
          <NumberField
            value={baseSpeed}
            min={0}
            max={120}
            disabled={!canEdit}
            // Typing the race's own speed clears the override, so the sheet
            // follows the race again rather than pinning a copy of it.
            onCommit={(n) =>
              updateStats({ speedOverride: n === raceSpeed ? null : n }, "speed")
            }
          />
        </label>
        {featureSpeed.parts.length > 0 && (
          <span className="sm-combat__note">{featureSpeed.parts.join(" · ")}</span>
        )}
        {stats.speedOverride != null && raceSpeed != null && (
          <span className="sm-combat__note">Race speed {raceSpeed} ft</span>
        )}
        {tooHeavy && (
          <span className="sm-combat__note sm-combat__note--warn">
            −10 ft: {armor!.name} needs STR {armor!.strengthRequirement}
          </span>
        )}
      </div>

      <div className="sm-combat__tile">
        <span className="sm-stat__label">Hit Dice</span>
        <span className="sm-combat__big">
          {cls ? `${level}d${cls.hitDie}` : "—"}
        </span>
        {!cls && <span className="sm-combat__note">Pick a class.</span>}
      </div>
    </div>
  );
}

/**
 * The class's features up to the class's own level (079), plus its
 * archetype's once one is picked. Same level rule as the subclass picker: a
 * Fighter 2 / Wizard 3 sees Fighter features through level 2, not 5.
 *
 * A feature with linked options (095) carries a picker under its text: the
 * Fighter's, Paladin's and Ranger's Fighting Style, and Champion's
 * Additional Fighting Style. Each picker offers its own row's options in the
 * catalogue's order. An option the character already holds on another
 * feature is shown but disabled: the PHB says a style can't be taken twice,
 * and 095's unique (character_id, option_id) would refuse it anyway. A
 * pick is always one of its row's options, because 095's (feature_id,
 * option_id) FK says so. Defense and Archery change the AC tile and the
 * attack rows; the rest are display only (see KNOWN_ISSUES).
 */
function ClassFeatures({
  entry,
  catalog,
  options,
  picks,
  canEdit,
  writePick,
}: {
  entry: CharacterClassEntry | undefined;
  catalog: ClassFeature[];
  options: FeatureOption[];
  picks: FeaturePick[];
  canEdit: boolean;
  writePick: (write: FeaturePickWrite) => void;
}) {
  // A single pick changes by updating its own row, so the select's three
  // outcomes are three different writes.
  const setSingle = (featureId: string, pick: FeaturePick | undefined, optionId: string) => {
    if (!entry) return;
    if (!optionId) {
      if (pick) writePick({ kind: "remove", pickId: pick.id });
    } else if (pick) {
      writePick({ kind: "change", pickId: pick.id, optionId });
    } else {
      writePick({ kind: "add", entry, featureId, optionId });
    }
  };
  // Already ordered by level, then name, by getClassFeatures.
  const features = entry
    ? catalog.filter(
        (f) =>
          f.classId === entry.classId &&
          f.level <= entry.level &&
          (f.subclassId == null || f.subclassId === entry.subclassId),
      )
    : [];

  if (features.length === 0) {
    return (
      <p className="ch-empty">
        {entry ? "No features recorded for this class yet." : "Pick a class first."}
      </p>
    );
  }

  return (
    <ul className="sm-features">
      {features.map((f) => {
        const pick = picks.find(
          (p) => p.characterClassId === entry?.id && p.featureId === f.id,
        );
        const offered = options.filter((o) => f.optionIds.includes(o.id));
        const chosen = options.find((o) => o.id === pick?.optionId) ?? null;
        // Held anywhere else on this character, on any class entry.
        const takenElsewhere = new Set(
          picks.filter((p) => p !== pick).map((p) => p.optionId),
        );
        const kindLabel = (
          offered[0] ? FEATURE_OPTION_KIND_LABELS[offered[0].kind] : "Choice"
        ).toLowerCase();
        return (
          <li key={f.id} className="sm-feature">
            <div className="sm-feature__head">
              <span className="sm-feature__name">{f.name}</span>
              <span className="sm-feature__level">Level {f.level}</span>
            </div>
            <p className="sm-feature__text">{f.description}</p>
            {offered.length > 0 && f.pickSteps.length > 0 && entry && (
              <FeaturePickList
                feature={f}
                entry={entry}
                offered={offered}
                picks={picks}
                canEdit={canEdit}
                writePick={writePick}
              />
            )}
            {offered.length > 0 && f.pickSteps.length === 0 && (
              <div className="sm-feature__choice">
                <select
                  aria-label={`${f.name}: ${kindLabel}`}
                  value={pick?.optionId ?? ""}
                  disabled={!canEdit}
                  onChange={(e) => setSingle(f.id, pick, e.target.value)}
                >
                  <option value="">Choose a {kindLabel}...</option>
                  {offered.map((o) => (
                    <option key={o.id} value={o.id} disabled={takenElsewhere.has(o.id)}>
                      {o.name}
                      {optionSourceLabel(o)}
                      {takenElsewhere.has(o.id) ? " (already taken)" : ""}
                    </option>
                  ))}
                </select>
                {chosen && <p className="sm-feature__text">{chosen.description}</p>}
              </div>
            )}
          </li>
        );
      })}
    </ul>
  );
}

/** "(Tasha's)", "(Homebrew)" or nothing for the PHB, after an option's name. */
function optionSourceLabel(o: FeatureOption): string {
  if (o.source && o.source !== "phb") return ` (${SUBCLASS_SOURCE_LABELS[o.source]})`;
  return o.isHomebrew ? " (Homebrew)" : "";
}

/**
 * A feature that grants several picks from one list (122): Combat
 * Superiority's maneuvers. The chosen ones are listed with their text and a
 * remove button; a select adds another while the count is under the
 * allowance for this class's level. Options the character already holds,
 * here or on any other feature, aren't offered (095's option-once unique).
 * A level drop keeps every pick, so the count can read "4 of 3"; adding is
 * then closed until enough are removed.
 */
function FeaturePickList({
  feature,
  entry,
  offered,
  picks,
  canEdit,
  writePick,
}: {
  feature: ClassFeature;
  entry: CharacterClassEntry;
  offered: FeatureOption[];
  picks: FeaturePick[];
  canEdit: boolean;
  writePick: (write: FeaturePickWrite) => void;
}) {
  const mine = picks.filter(
    (p) => p.characterClassId === entry.id && p.featureId === feature.id,
  );
  const allowed = picksAllowed(feature.pickSteps, entry.level);
  const held = new Set(picks.map((p) => p.optionId));
  const byId = new Map(offered.map((o) => [o.id, o]));
  const kind = FEATURE_OPTION_KIND_LABELS[offered[0].kind].toLowerCase();

  return (
    <div className="sm-feature__choice">
      <p className="sm-feature__count">
        {mine.length} of {allowed} {kind}s chosen
      </p>
      {mine.length > 0 && (
        <ul className="sm-picks">
          {mine.map((p) => {
            const o = byId.get(p.optionId);
            return (
              <li key={p.id} className="sm-pick">
                <div className="sm-pick__head">
                  <span className="sm-pick__name">
                    {o ? o.name + optionSourceLabel(o) : "Unknown option"}
                  </span>
                  {canEdit && (
                    <button
                      type="button"
                      className="sm-pick__remove"
                      aria-label={`Remove ${o?.name ?? "this pick"}`}
                      onClick={() => writePick({ kind: "remove", pickId: p.id })}
                    >
                      ×
                    </button>
                  )}
                </div>
                {o && <p className="sm-feature__text">{o.description}</p>}
              </li>
            );
          })}
        </ul>
      )}
      {mine.length > allowed && (
        <p className="sm-legend">
          More than this level allows: remove {mine.length - allowed} to match.
        </p>
      )}
      {canEdit && mine.length < allowed && (
        <select
          aria-label={`${feature.name}: add a ${kind}`}
          value=""
          onChange={(e) =>
            e.target.value &&
            writePick({ kind: "add", entry, featureId: feature.id, optionId: e.target.value })
          }
        >
          <option value="">Add a {kind}...</option>
          {offered
            .filter((o) => !held.has(o.id))
            .map((o) => (
              <option key={o.id} value={o.id}>
                {o.name}
                {optionSourceLabel(o)}
                {o.prerequisite ? ` (${o.prerequisite})` : ""}
              </option>
            ))}
        </select>
      )}
    </div>
  );
}

/**
 * One row per weapon carried, plus an unarmed strike. To-hit and damage are
 * derived. A weapon counts as proficient when the class's training covers its
 * category, or when the character has a 'weapon' proficiency row for that
 * item (056) — the way a Rogue gets rapiers. A class-granted proficiency can't
 * be switched off here, because "no row" already means "nothing extra".
 * Archery's +2 is added to a ranged row's to-hit and named in its tooltip.
 */
function AttacksBlock({
  weapons,
  proficiencies,
  canEdit,
  toggleProf,
  cls,
  pb,
  strMod,
  dexMod,
  intMod,
  styles,
  effects,
  unarmored,
}: {
  weapons: WeaponEntry[];
  proficiencies: Proficiency[];
  canEdit: boolean;
  toggleProf: (itemId: string, proficient: boolean) => void;
  cls: CharacterClass | null;
  pb: number;
  strMod: number;
  dexMod: number;
  /** Battle Ready's ability on a magic weapon. */
  intMod: number;
  styles: readonly FightingStyleKey[];
  effects: EffectLevels;
  /** No body armour and no shield: the condition Martial Arts needs. */
  unarmored: boolean;
}) {
  const extra = new Set(
    proficiencies.filter((p) => p.kind === "weapon").map((p) => p.key),
  );
  // Battle Ready raises a Battle Smith's training to martial.
  const training = weaponTraining(cls?.weaponTraining ?? null, effects);
  const fromClass = (w: WeaponEntry) =>
    w.category === "simple" || training === "martial";
  const mods = { str: strMod, dex: dexMod, int: intMod };
  const better = Math.max(strMod, dexMod);

  // The facts that apply to every attack, shown once above the rows.
  const attacks = attacksPerAction(effects);
  const crit = critThreshold(effects);
  const sneak = sneakAttackDice(effects);
  const maDie = martialArtsDie(effects);
  const martial = maDie != null && unarmored;
  const summary = [
    attacks > 1 && `${attacks} attacks per Attack action`,
    crit < 20 && `crit on ${crit}–20`,
    sneak > 0 && `Sneak Attack ${sneak}d6 once per turn (finesse or ranged)`,
    maDie != null &&
      (martial
        ? `Martial Arts d${maDie}`
        : `Martial Arts d${maDie} needs no armour or shield`),
  ].filter(Boolean);

  return (
    <>
      <Band label="Attacks" count={`${weapons.length} carried`} />
      <div className="ch-body">
        {summary.length > 0 && <p className="sm-legend">{summary.join(" · ")}</p>}
        <table className="ch-table sm-attacks">
          <tbody>
            {weapons.map((w) => {
              // Martial Arts lets a monk weapon use DEX and its die.
              const ma = martialArtsWeapon(w, maDie, unarmored);
              const base = ma.finesse
                ? dexMod > strMod
                  ? "dex"
                  : "str"
                : weaponAbility(w, strMod, dexMod);
              // Battle Ready: INT on a magic weapon, when it's higher.
              const ability = battleReadyAbility(base, mods, w.rarity !== null, effects);
              const abilityMod =
                ability === "int" ? intMod : ability === "dex" ? dexMod : strMod;
              const classProf = fromClass(w);
              const proficient = classProf || extra.has(w.id);
              const styleBonus = styleAttackBonus(w, styles);
              const toHit = abilityMod + (proficient ? pb : 0) + styleBonus;
              return (
                <tr key={w.entryId}>
                  <td className="sm-attacks__prof">
                    <button
                      type="button"
                      className={`sm-pip sm-pip--${proficient ? 1 : 0}`}
                      title={
                        classProf
                          ? "Proficient from class"
                          : proficient
                            ? "Proficient (added)"
                            : "Not proficient"
                      }
                      aria-label={`${w.name}: ${proficient ? "proficient" : "not proficient"}`}
                      disabled={!canEdit || classProf}
                      onClick={() => toggleProf(w.id, !proficient)}
                    />
                  </td>
                  <td>
                    {w.customName ?? w.name}
                    <span className="sm-attacks__meta">
                      {[
                        w.category,
                        ...w.properties,
                        w.rangeNormal != null &&
                          `${w.rangeNormal}/${w.rangeLong ?? w.rangeNormal} ft`,
                      ]
                        .filter(Boolean)
                        .join(" · ")}
                    </span>
                  </td>
                  <td
                    className="sm-attacks__hit"
                    title={styleBonus ? `Includes Archery ${formatModifier(styleBonus)}` : undefined}
                  >
                    {formatModifier(toHit)}
                  </td>
                  <td className="sm-attacks__dmg">
                    {damageString(ma.dice, abilityMod)} {w.damageType}
                    {w.versatileDice && (
                      <span className="sm-attacks__meta">
                        two-handed {damageString(w.versatileDice, abilityMod)}
                      </span>
                    )}
                  </td>
                </tr>
              );
            })}
            {/* Everyone is proficient with unarmed strikes: 1 + STR, or with
                Martial Arts the die + the better of STR and DEX. */}
            <tr>
              <td className="sm-attacks__prof">
                <span className="sm-pip sm-pip--1" />
              </td>
              <td>
                Unarmed Strike
                <span className="sm-attacks__meta">
                  {martial ? "Martial Arts" : "always proficient"}
                </span>
              </td>
              <td className="sm-attacks__hit">
                {formatModifier((martial ? better : strMod) + pb)}
              </td>
              <td className="sm-attacks__dmg">
                {martial
                  ? damageString(`1d${maDie}`, better)
                  : Math.max(1, 1 + strMod)}{" "}
                bludgeoning
              </td>
            </tr>
          </tbody>
        </table>
        {weapons.length === 0 && (
          <p className="sm-legend">
            No weapons carried — buy or take one from the hoard to see it here.
          </p>
        )}
      </div>
    </>
  );
}

/**
 * A number input that saves on blur or Enter rather than on every keystroke:
 * typing "15" would otherwise write 1 and then 15, and a cleared field would
 * try to save nothing. Escape reverts. The draft re-syncs from `value` when
 * the server's number changes (another device, the DM) while the field isn't
 * being edited.
 */
function NumberField({
  value,
  min,
  max,
  onCommit,
  disabled,
  className,
  title,
  "aria-label": ariaLabel,
}: {
  value: number;
  min: number;
  max: number;
  onCommit: (n: number) => void;
  disabled?: boolean;
  className?: string;
  title?: string;
  "aria-label"?: string;
}) {
  const [draft, setDraft] = useState(String(value));
  const [editing, setEditing] = useState(false);
  // Set by Escape so the blur that follows doesn't commit the abandoned
  // draft: the blur handler would otherwise still see it in its closure.
  const cancelled = useRef(false);

  useEffect(() => {
    if (!editing) setDraft(String(value));
  }, [value, editing]);

  const commit = () => {
    setEditing(false);
    if (cancelled.current) {
      cancelled.current = false;
      setDraft(String(value));
      return;
    }
    const n = Number.parseInt(draft, 10);
    if (Number.isNaN(n)) {
      setDraft(String(value));
      return;
    }
    const clamped = Math.min(max, Math.max(min, n));
    setDraft(String(clamped));
    if (clamped !== value) onCommit(clamped);
  };

  const onKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") e.currentTarget.blur();
    if (e.key === "Escape") {
      cancelled.current = true;
      e.currentTarget.blur();
    }
  };

  return (
    <input
      type="number"
      className={className}
      min={min}
      max={max}
      value={draft}
      disabled={disabled}
      title={title}
      aria-label={ariaLabel}
      onFocus={() => setEditing(true)}
      onChange={(e) => setDraft(e.target.value)}
      onBlur={commit}
      onKeyDown={onKeyDown}
    />
  );
}

const PROF_LABELS: Record<ProficiencyLevel, string> = {
  0: "Untrained",
  1: "Proficient",
  2: "Expertise",
};

function Stat({ label, value, title }: { label: string; value: string; title?: string }) {
  return (
    <div className="sm-stat" title={title}>
      <span className="sm-stat__label">{label}</span>
      <span className="sm-stat__value">{value}</span>
    </div>
  );
}
