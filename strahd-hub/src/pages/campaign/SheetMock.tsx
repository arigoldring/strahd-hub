import { useState } from "react";
import { useCampaign } from "../../components/CampaignLayout";
import { useAuth } from "../../services/AuthContext";
import { useCharacter } from "../../hooks/useCharacter";
import { useParty } from "../../hooks/useParty";
import { useSheetMock, type SheetMockState } from "../../hooks/useSheetMock";
import {
  ABILITIES,
  ABILITY_LABELS,
  SKILLS,
  abilityModifier,
  formatModifier,
  proficiencyBonus,
  skillBonus,
  type Ability,
  type ProficiencyLevel,
  type SkillKey,
} from "../../data/rules";
import type { Character as CharacterModel } from "../../services/characters";
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

  // Everything below is derived on render from the few values typed in.
  const pb = proficiencyBonus(sheet.level);
  const mod = (a: Ability) => abilityModifier(sheet.scores[a]);
  const skillTotal = (key: SkillKey) => {
    const skill = SKILLS.find((s) => s.key === key)!;
    return skillBonus(mod(skill.ability), pb, sheet.skills[key]);
  };
  const spellMod = mod(sheet.spellAbility);

  return (
    <article className="ch-sheet">
      <header className="ch-head">
        <p className="ch-eyebrow">— Full Sheet (mock) —</p>
        <div className="ch-identity">
          <h1 className="ch-name">{character.name}</h1>
        </div>
        <div className="sm-classline">
          <label>
            <span>Class</span>
            <input
              type="text"
              value={sheet.className}
              placeholder="e.g. Cleric"
              onChange={(e) => update({ className: e.target.value })}
            />
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
              update({ spellAbility: e.target.value as Ability })
            }
          >
            {ABILITIES.map((a) => (
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
