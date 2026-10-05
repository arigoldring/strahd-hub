import { KeyboardEvent, useEffect, useRef, useState } from "react";
import { useCampaign } from "../../components/CampaignLayout";
import { useAuth } from "../../services/AuthContext";
import { useCharacter } from "../../hooks/useCharacter";
import { useParty } from "../../hooks/useParty";
import { useCharacterInventory } from "../../hooks/useCharacterInventory";
import { useCharacterSheet } from "../../hooks/useCharacterSheet";
import { useClasses } from "../../hooks/useClasses";
import { useRaces } from "../../hooks/useRaces";
import {
  ABILITIES,
  ABILITY_LABELS,
  SKILLS,
  abilityModifier,
  armorClass,
  averageHp,
  damageString,
  formatModifier,
  proficiencyBonus,
  skillBonus,
  totalLevel,
  weaponAbility,
  type Ability,
  type ProficiencyLevel,
  type SkillKey,
} from "../../data/rules";
import {
  saveSet,
  skillLevels,
  type CharacterStats,
  type CharacterStatsPatch,
  type Proficiency,
} from "../../services/characterSheet";
import type { CharacterClass } from "../../services/classes";
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
  const { data: races = [] } = useRaces(campaign.id);
  // Same key as the Carried section below, so this is a cache hit.
  const { data: gear = [], setEquipped } = useCharacterInventory(character.id);

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

  const { stats, classes, proficiencies } = sheetQuery.data;
  const updateStats = (patch: CharacterStatsPatch, what: string) =>
    run(sheetQuery.updateStats(patch), what);

  // ---- derived, every render ----
  const startingEntry = classes.find((c) => c.isStarting) ?? classes[0];
  const cls = classCatalog.find((c) => c.id === startingEntry?.classId) ?? null;
  const race = races.find((r) => r.id === stats.raceId) ?? null;
  const level = totalLevel(classes);
  const pb = proficiencyBonus(level);
  const mod = (a: Ability) => abilityModifier(stats.scores[a]);
  const saves = saveSet(proficiencies);
  const skills = skillLevels(proficiencies);
  const skillTotal = (key: SkillKey) => {
    const skill = SKILLS.find((s) => s.key === key)!;
    return skillBonus(mod(skill.ability), pb, skills[key]);
  };
  const spellAbility = cls?.spellAbility ?? null;

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
    bonus: stats.acBonus,
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
      />

      <div className="sm-derived">
        <Stat label="Proficiency" value={formatModifier(pb)} />
        <Stat label="Initiative" value={formatModifier(mod("dex"))} />
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
                      <span className="sm-row__total">
                        {formatModifier(mod(a) + (saves.has(a) ? pb : 0))}
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
          />
          <CharacterSpells characterId={character.id} isOwn={isOwn} />
          <CharacterFeats characterId={character.id} isOwn={isOwn} />
          <CharacterCarried characterId={character.id} isOwn={isOwn} />
          <CharacterPurse character={character} />

          <Band label="Class Features" />
          <div className="ch-body">
            <p className="ch-empty">Coming later.</p>
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
}) {
  const bodyArmors = armors.filter((a) => a.category !== "shield");
  const shields = armors.filter((a) => a.category === "shield");
  const [hpDelta, setHpDelta] = useState("");

  const baseSpeed = stats.speedOverride ?? raceSpeed ?? 30;
  // Heavy armour without the Strength for it costs 10 ft of speed (PHB).
  const tooHeavy =
    armor?.strengthRequirement != null &&
    stats.scores.str < armor.strengthRequirement;
  const speed = Math.max(0, baseSpeed - (tooHeavy ? 10 : 0));

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
            Average for level {level}: {averageHp(cls.hitDie, level, conMod)}
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
 * One row per weapon carried, plus an unarmed strike. To-hit and damage are
 * derived. A weapon counts as proficient when the class's training covers its
 * category, or when the character has a 'weapon' proficiency row for that
 * item (056) — the way a Rogue gets rapiers. A class-granted proficiency can't
 * be switched off here, because "no row" already means "nothing extra".
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
}: {
  weapons: WeaponEntry[];
  proficiencies: Proficiency[];
  canEdit: boolean;
  toggleProf: (itemId: string, proficient: boolean) => void;
  cls: CharacterClass | null;
  pb: number;
  strMod: number;
  dexMod: number;
}) {
  const extra = new Set(
    proficiencies.filter((p) => p.kind === "weapon").map((p) => p.key),
  );
  const fromClass = (w: WeaponEntry) =>
    w.category === "simple" || cls?.weaponTraining === "martial";

  return (
    <>
      <Band label="Attacks" count={`${weapons.length} carried`} />
      <div className="ch-body">
        <table className="ch-table sm-attacks">
          <tbody>
            {weapons.map((w) => {
              const ability = weaponAbility(w, strMod, dexMod);
              const abilityMod = ability === "dex" ? dexMod : strMod;
              const classProf = fromClass(w);
              const proficient = classProf || extra.has(w.id);
              const toHit = abilityMod + (proficient ? pb : 0);
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
                  <td className="sm-attacks__hit">{formatModifier(toHit)}</td>
                  <td className="sm-attacks__dmg">
                    {damageString(w.damageDice, abilityMod)} {w.damageType}
                    {w.versatileDice && (
                      <span className="sm-attacks__meta">
                        two-handed {damageString(w.versatileDice, abilityMod)}
                      </span>
                    )}
                  </td>
                </tr>
              );
            })}
            {/* Everyone is proficient with unarmed strikes: 1 + STR. */}
            <tr>
              <td className="sm-attacks__prof">
                <span className="sm-pip sm-pip--1" />
              </td>
              <td>
                Unarmed Strike
                <span className="sm-attacks__meta">always proficient</span>
              </td>
              <td className="sm-attacks__hit">{formatModifier(strMod + pb)}</td>
              <td className="sm-attacks__dmg">{Math.max(1, 1 + strMod)} bludgeoning</td>
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

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="sm-stat">
      <span className="sm-stat__label">{label}</span>
      <span className="sm-stat__value">{value}</span>
    </div>
  );
}
