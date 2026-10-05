import { useState } from "react";
import { useCampaign } from "../../components/CampaignLayout";
import { useAuth } from "../../services/AuthContext";
import { useCharacter } from "../../hooks/useCharacter";
import { useParty } from "../../hooks/useParty";
import { useCharacterInventory } from "../../hooks/useCharacterInventory";
import { useSheetMock, type SheetMockState } from "../../hooks/useSheetMock";
import {
  ABILITIES,
  ABILITY_LABELS,
  CLASSES,
  RACES,
  SKILLS,
  SPELL_ABILITIES,
  abilityModifier,
  armorClass,
  averageHp,
  damageString,
  weaponAbility,
  formatModifier,
  proficiencyBonus,
  skillBonus,
  type Ability,
  type ClassInfo,
  type ClassName,
  type ProficiencyLevel,
  type SkillKey,
  type SpellAbility,
} from "../../data/rules";
import type { Character as CharacterModel } from "../../services/characters";
import type { CharacterInventoryEntry } from "../../services/characterInventory";
import type { Armor, Weapon } from "../../services/items";
import {
  Band,
  CharacterCarried,
  CharacterFeats,
  CharacterPurse,
  CharacterSpells,
} from "./Character";
import "./character.css";
import "./sheetMock.css";

/**
 * MOCK-UP: what a full character sheet could look like. Abilities, saves and
 * skills are local to this browser (useSheetMock); spells, feats, gear and
 * purse are the character's real data through the Character page's own
 * sections. Nothing here writes a new column — see useSheetMock's header.
 *
 * A DM has no PC, and is also the person reviewing this mock, so they get a
 * picker over the party instead of the create flow.
 */
export function SheetMock() {
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
      <p className="ch-empty">
        Create a character on the Character page first.
      </p>
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
      {/* Keyed so switching character remounts the sheet and useSheetMock
          loads the new character's saved numbers. */}
      <FullSheet
        key={character.id}
        character={character}
        isOwn={character.userId === profile?.id}
      />
    </>
  );
}

function FullSheet({
  character,
  isOwn,
}: {
  character: CharacterModel;
  isOwn: boolean;
}) {
  const [sheet, setSheet] = useSheetMock(character.id);
  const update = (patch: Partial<SheetMockState>) =>
    setSheet((s) => ({ ...s, ...patch }));

  // Picking a class replaces the save proficiencies with that class's two,
  // and sets the casting ability when the class has one. Both stay editable
  // afterwards (multiclassing, a subclass caster), so this is a starting
  // point, not a lock. Clearing the class leaves both alone.
  const pickClass = (name: ClassName | "") => {
    const cls = CLASSES.find((c) => c.name === name);
    if (!cls) return update({ className: "" });
    update({
      className: cls.name,
      saves: Object.fromEntries(
        ABILITIES.map((a) => [a, (cls.saves as readonly Ability[]).includes(a)]),
      ) as Record<Ability, boolean>,
      ...(cls.spellAbility && { spellAbility: cls.spellAbility }),
    });
  };

  // Everything below is derived on render from the few values typed in.
  const pb = proficiencyBonus(sheet.level);
  const mod = (a: Ability) => abilityModifier(sheet.scores[a]);
  const skillTotal = (key: SkillKey) => {
    const skill = SKILLS.find((s) => s.key === key)!;
    return skillBonus(mod(skill.ability), pb, sheet.skills[key]);
  };
  const spellMod = mod(sheet.spellAbility);
  const cls = CLASSES.find((c) => c.name === sheet.className) ?? null;

  // Armour and weapons come from what the character is actually carrying.
  // Same query key as the Carried section below, so this is a cache hit, not
  // a second request.
  const { data: gear = [] } = useCharacterInventory(character.id);
  const armors = gear.filter(
    (i): i is CharacterInventoryEntry & Armor => i.kind === "armor",
  );
  const weapons = gear.filter(
    (i): i is CharacterInventoryEntry & Weapon => i.kind === "weapon",
  );
  // An id that no longer matches anything carried (sold, stowed) simply
  // counts as unequipped.
  const armor =
    armors.find((a) => a.id === sheet.armorId && a.category !== "shield") ??
    null;
  const shield =
    armors.find((a) => a.id === sheet.shieldId && a.category === "shield") ??
    null;
  const ac = armorClass({
    armor,
    shield,
    dexMod: mod("dex"),
    cls,
    unarmoredMod: cls?.unarmored ? mod(cls.unarmored) : 0,
    bonus: sheet.acBonus,
  });

  return (
    <article className="ch-sheet">
      <header className="ch-head">
        <p className="ch-eyebrow">— Full Sheet (mock) —</p>
        <div className="ch-identity">
          <h1 className="ch-name">{character.name}</h1>
        </div>
        <div className="sm-classline">
          <label>
            <span>Race</span>
            <select
              value={sheet.race}
              onChange={(e) => {
                // Like class → saves: picking a race sets the speed, which
                // stays editable afterwards (Wood Elf, the Mobile feat).
                const race = RACES.find((r) => r.name === e.target.value);
                update(
                  race
                    ? { race: race.name, speed: race.speed }
                    : { race: "" },
                );
              }}
            >
              <option value="">Choose a race...</option>
              {RACES.map((r) => (
                <option key={r.name} value={r.name}>
                  {r.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            <span>Class</span>
            <select
              value={sheet.className}
              onChange={(e) => pickClass(e.target.value as ClassName | "")}
            >
              <option value="">Choose a class...</option>
              {CLASSES.map((c) => (
                <option key={c.name} value={c.name}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            <span>Level</span>
            <input
              type="number"
              min={1}
              max={20}
              value={sheet.level}
              onChange={(e) =>
                update({ level: clampInt(e.target.value, 1, 20, sheet.level) })
              }
            />
          </label>
        </div>
      </header>

      <CombatBlock
        sheet={sheet}
        update={update}
        cls={cls}
        conMod={mod("con")}
        strScore={sheet.scores.str}
        ac={ac}
        armor={armor}
        armors={armors}
      />

      <div className="sm-derived">
        <Stat label="Proficiency" value={formatModifier(pb)} />
        <Stat label="Initiative" value={formatModifier(mod("dex"))} />
        <Stat
          label="Passive Perception"
          value={String(10 + skillTotal("perception"))}
        />
        <Stat
          label="Passive Investigation"
          value={String(10 + skillTotal("investigation"))}
        />
        <Stat label="Passive Insight" value={String(10 + skillTotal("insight"))} />
        <Stat label="Spell Save DC" value={String(8 + pb + spellMod)} />
        <Stat label="Spell Attack" value={formatModifier(pb + spellMod)} />
        <label className="sm-stat sm-stat--select">
          <span className="sm-stat__label">Casting Ability</span>
          <select
            value={sheet.spellAbility}
            onChange={(e) =>
              update({ spellAbility: e.target.value as SpellAbility })
            }
          >
            {SPELL_ABILITIES.map((a) => (
              <option key={a} value={a}>
                {ABILITY_LABELS[a]}
              </option>
            ))}
          </select>
        </label>
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
                  <input
                    className="sm-ability__score"
                    type="number"
                    min={1}
                    max={30}
                    value={sheet.scores[a]}
                    onChange={(e) =>
                      update({
                        scores: {
                          ...sheet.scores,
                          [a]: clampInt(e.target.value, 1, 30, sheet.scores[a]),
                        },
                      })
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
                        checked={sheet.saves[a]}
                        onChange={(e) =>
                          update({
                            saves: { ...sheet.saves, [a]: e.target.checked },
                          })
                        }
                      />
                      <span className="sm-row__name">{ABILITY_LABELS[a]}</span>
                      <span className="sm-row__total">
                        {formatModifier(mod(a) + (sheet.saves[a] ? pb : 0))}
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
                  const prof = sheet.skills[s.key];
                  return (
                    <li key={s.key} className="sm-row">
                      <button
                        type="button"
                        className={`sm-pip sm-pip--${prof}`}
                        title={PROF_LABELS[prof]}
                        aria-label={`${s.label}: ${PROF_LABELS[prof]}`}
                        onClick={() =>
                          update({
                            skills: {
                              ...sheet.skills,
                              [s.key]: ((prof + 1) % 3) as ProficiencyLevel,
                            },
                          })
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
            sheet={sheet}
            update={update}
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

type Update = (patch: Partial<SheetMockState>) => void;
type ArmorEntry = CharacterInventoryEntry & Armor;
type WeaponEntry = CharacterInventoryEntry & Weapon;

/**
 * AC, HP, speed and hit dice: the numbers read most often mid-fight, so they
 * sit full width directly under the name. AC is derived from the armour
 * picked here out of the character's real inventory; HP and speed are typed.
 */
function CombatBlock({
  sheet,
  update,
  cls,
  conMod,
  strScore,
  ac,
  armor,
  armors,
}: {
  sheet: SheetMockState;
  update: Update;
  cls: ClassInfo | null;
  conMod: number;
  strScore: number;
  ac: { total: number; parts: string[] };
  armor: ArmorEntry | null;
  armors: ArmorEntry[];
}) {
  const bodyArmors = armors.filter((a) => a.category !== "shield");
  const shields = armors.filter((a) => a.category === "shield");
  // Heavy armour without the Strength for it costs 10 ft of speed (PHB).
  const tooHeavy =
    armor?.strengthRequirement != null && strScore < armor.strengthRequirement;
  const speed = Math.max(0, sheet.speed - (tooHeavy ? 10 : 0));

  return (
    <div className="sm-combat">
      <div className="sm-combat__tile">
        <span className="sm-stat__label">Armor Class</span>
        <span className="sm-combat__big">{ac.total}</span>
        <span className="sm-combat__note">{ac.parts.join(" · ")}</span>
        <div className="sm-combat__controls">
          <select
            aria-label="Armor worn"
            value={sheet.armorId ?? ""}
            onChange={(e) => update({ armorId: e.target.value || null })}
          >
            <option value="">No armor</option>
            {bodyArmors.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name} ({a.category})
              </option>
            ))}
          </select>
          {shields.length > 0 && (
            <select
              aria-label="Shield"
              value={sheet.shieldId ?? ""}
              onChange={(e) => update({ shieldId: e.target.value || null })}
            >
              <option value="">No shield</option>
              {shields.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name}
                </option>
              ))}
            </select>
          )}
          <label className="sm-combat__inline">
            <span>Other</span>
            <input
              type="number"
              value={sheet.acBonus}
              onChange={(e) =>
                update({
                  acBonus: clampInt(e.target.value, -10, 10, sheet.acBonus),
                })
              }
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
          <input
            className="sm-hp__current"
            type="number"
            aria-label="Current HP"
            value={sheet.hpCurrent}
            onChange={(e) =>
              update({
                hpCurrent: clampInt(e.target.value, -999, 999, sheet.hpCurrent),
              })
            }
          />
          <span className="sm-hp__slash">/</span>
          <input
            type="number"
            aria-label="Max HP"
            min={1}
            value={sheet.hpMax}
            onChange={(e) =>
              update({ hpMax: clampInt(e.target.value, 1, 999, sheet.hpMax) })
            }
          />
        </div>
        <label className="sm-combat__inline">
          <span>Temp</span>
          <input
            type="number"
            min={0}
            value={sheet.hpTemp}
            onChange={(e) =>
              update({ hpTemp: clampInt(e.target.value, 0, 999, sheet.hpTemp) })
            }
          />
        </label>
        {cls && (
          <span className="sm-combat__note">
            Average for level {sheet.level}:{" "}
            {averageHp(cls.hitDie, sheet.level, conMod)}
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
          <input
            type="number"
            min={0}
            step={5}
            value={sheet.speed}
            onChange={(e) =>
              update({ speed: clampInt(e.target.value, 0, 120, sheet.speed) })
            }
          />
        </label>
        {tooHeavy && (
          <span className="sm-combat__note sm-combat__note--warn">
            −10 ft: {armor!.name} needs STR {armor!.strengthRequirement}
          </span>
        )}
      </div>

      <div className="sm-combat__tile">
        <span className="sm-stat__label">Hit Dice</span>
        <span className="sm-combat__big">
          {cls ? `${sheet.level}d${cls.hitDie}` : "—"}
        </span>
        {!cls && <span className="sm-combat__note">Pick a class.</span>}
      </div>
    </div>
  );
}

/**
 * One row per weapon carried, plus an unarmed strike. To-hit and damage are
 * derived: the ability from weaponAbility (DEX for ranged, the better of
 * STR/DEX for finesse), proficiency from the class's simple/martial default
 * unless that weapon's pip has been toggled by hand.
 */
function AttacksBlock({
  weapons,
  sheet,
  update,
  cls,
  pb,
  strMod,
  dexMod,
}: {
  weapons: WeaponEntry[];
  sheet: SheetMockState;
  update: Update;
  cls: ClassInfo | null;
  pb: number;
  strMod: number;
  dexMod: number;
}) {
  const classProficient = (w: WeaponEntry) =>
    w.category === "simple" || cls?.weapons === "martial";

  return (
    <>
      <Band label="Attacks" count={`${weapons.length} carried`} />
      <div className="ch-body">
        <table className="ch-table sm-attacks">
          <tbody>
            {weapons.map((w) => {
              const ability = weaponAbility(w, strMod, dexMod);
              const abilityMod = ability === "dex" ? dexMod : strMod;
              const proficient = sheet.weaponProf[w.id] ?? classProficient(w);
              const toHit = abilityMod + (proficient ? pb : 0);
              return (
                <tr key={w.entryId}>
                  <td className="sm-attacks__prof">
                    <button
                      type="button"
                      className={`sm-pip sm-pip--${proficient ? 1 : 0}`}
                      title={proficient ? "Proficient" : "Not proficient"}
                      aria-label={`${w.name}: ${proficient ? "proficient" : "not proficient"}`}
                      onClick={() =>
                        update({
                          weaponProf: { ...sheet.weaponProf, [w.id]: !proficient },
                        })
                      }
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
              <td className="sm-attacks__dmg">
                {Math.max(1, 1 + strMod)} bludgeoning
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

// A number input hands back "" mid-edit; keep the current value rather than
// store NaN or snap to a default under the cursor.
function clampInt(raw: string, min: number, max: number, current: number) {
  const n = Number.parseInt(raw, 10);
  if (Number.isNaN(n)) return current;
  return Math.min(max, Math.max(min, n));
}
