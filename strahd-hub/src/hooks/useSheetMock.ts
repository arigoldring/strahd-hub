import { useEffect, useState } from "react";
import {
  ABILITIES,
  SKILLS,
  type Ability,
  type ProficiencyLevel,
  type SkillKey,
} from "../data/rules";

/**
 * MOCK-ONLY SCAFFOLDING. The full-sheet mock-up's numbers — level, class,
 * ability scores, proficiencies — live in this browser's localStorage, keyed
 * per character, because `characters` has no columns for any of them and the
 * point of the mock is to look before deciding the schema.
 *
 * If the sheet becomes real, this state moves to the database (columns on
 * `characters` or a `character_stats` sibling table), and with it the
 * pin-trigger gotcha in CLAUDE.md: pin_character_row is a blocklist, so any
 * new column is client-writable until someone decides otherwise. Nothing here
 * is shared between devices or visible to the DM on another machine.
 */
export interface SheetMockState {
  level: number;
  className: string;
  spellAbility: Ability;
  scores: Record<Ability, number>;
  saves: Record<Ability, boolean>;
  skills: Record<SkillKey, ProficiencyLevel>;
}

function defaults(): SheetMockState {
  return {
    level: 1,
    className: "",
    spellAbility: "int",
    scores: Object.fromEntries(ABILITIES.map((a) => [a, 10])) as Record<
      Ability,
      number
    >,
    saves: Object.fromEntries(ABILITIES.map((a) => [a, false])) as Record<
      Ability,
      boolean
    >,
    skills: Object.fromEntries(SKILLS.map((s) => [s.key, 0])) as Record<
      SkillKey,
      ProficiencyLevel
    >,
  };
}

const storageKey = (characterId: string) => `sheet-mock:${characterId}`;

// Merged over the defaults rather than trusted whole, so a value saved by an
// older shape of this mock (a skill added since, say) still loads.
function load(characterId: string): SheetMockState {
  const base = defaults();
  try {
    const raw = localStorage.getItem(storageKey(characterId));
    if (!raw) return base;
    const saved = JSON.parse(raw) as Partial<SheetMockState>;
    return {
      ...base,
      ...saved,
      scores: { ...base.scores, ...saved.scores },
      saves: { ...base.saves, ...saved.saves },
      skills: { ...base.skills, ...saved.skills },
    };
  } catch {
    return base;
  }
}

export function useSheetMock(characterId: string) {
  // Keyed state: when the DM switches character, the page remounts this hook's
  // owner with a new key (see SheetMock), so the initializer reruns.
  const [state, setState] = useState(() => load(characterId));

  useEffect(() => {
    try {
      localStorage.setItem(storageKey(characterId), JSON.stringify(state));
    } catch {
      // Private window or blocked storage: the sheet still works, it just
      // forgets on refresh.
    }
  }, [characterId, state]);

  return [state, setState] as const;
}
