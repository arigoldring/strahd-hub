import { KeyboardEvent, useEffect, useRef, useState, type ReactNode } from "react";
import { Band } from "./Character";
import { NumberField } from "./NumberField";
import {
  ABILITIES,
  formatModifier,
  abilityModifier,
  type SteelDefenderBlock,
} from "../../data/rules";
import {
  COMPANION_DEFAULT_NAMES,
  defaultCompanion,
  normalizeCompanionName,
  type Companion,
  type CompanionPatch,
} from "../../services/companions";
import { errorMessage } from "../../lib/errors";

/**
 * The Battle Smith's steel defender (167): its own HP, AC and everything it
 * can do. Shown when the character has the steel_defender effect (168 puts
 * it on the Steel Defender feature), never by matching the subclass's name.
 *
 * The block's numbers come from rules.ts (steelDefender). Only the name,
 * damage taken and temp HP are stored; a missing row is a full-health
 * defender with the default name.
 *
 * The companions query and its mutations live in FullSheet, which needs the
 * rest action for the Long Rest button, and are passed in.
 */
export function SheetSteelDefender({
  block,
  companion: stored,
  isLoading,
  loadError,
  canEdit,
  adjustHp,
  save,
}: {
  block: SteelDefenderBlock;
  companion: Companion | undefined;
  isLoading: boolean;
  loadError: Error | null;
  canEdit: boolean;
  adjustHp: (delta: number, cap: number) => Promise<unknown>;
  save: (current: Companion, patch: CompanionPatch) => Promise<unknown>;
}) {
  const companion = stored ?? defaultCompanion("steel_defender");
  const [hpDelta, setHpDelta] = useState("");
  const [saveError, setSaveError] = useState<string | null>(null);

  const run = (action: Promise<unknown>, what: string) => {
    setSaveError(null);
    action.catch((err) => setSaveError(errorMessage(err, `Couldn't save ${what}`)));
  };
  const write = (patch: CompanionPatch, what: string) => run(save(companion, patch), what);

  // A damage row above a lowered maximum (a level drop) shows as 0 HP, and
  // the next write clamps it, 153's rule for counters.
  const current = block.maxHp - Math.min(companion.damage, block.maxHp);
  const applyHp = (sign: 1 | -1) => {
    const n = Number.parseInt(hpDelta, 10);
    if (!Number.isNaN(n) && n > 0) {
      run(adjustHp(sign * n, block.maxHp), "its HP");
      setHpDelta("");
    }
  };

  // A missing row means full HP, so it mustn't be shown before the read has
  // answered, or a damaged defender flashes healthy.
  if (isLoading || loadError) {
    return (
      <section>
        <Band label={COMPANION_DEFAULT_NAMES.steel_defender} />
        <div className="ch-body">
          {loadError ? (
            <p className="ch-error">{loadError.message}</p>
          ) : (
            <p className="ch-empty">Winding the gears...</p>
          )}
        </div>
      </section>
    );
  }

  return (
    <section>
      <Band label={COMPANION_DEFAULT_NAMES.steel_defender} />
      <div className="ch-body sm-companion">
        {saveError && <p className="ch-error">{saveError}</p>}
        <label className="sm-companion__name">
          <span>Name</span>
          <TextField
            value={companion.name ?? ""}
            placeholder={COMPANION_DEFAULT_NAMES.steel_defender}
            maxLength={40}
            disabled={!canEdit}
            onCommit={(text) => write({ name: normalizeCompanionName(text) }, "its name")}
          />
        </label>

        <div className="sm-companion__combat">
          <div className="sm-combat__tile">
            <span className="sm-stat__label">Armor Class</span>
            <span className="sm-combat__big">{block.ac}</span>
            <span className="sm-combat__note">{block.acNote}</span>
          </div>
          <div className="sm-combat__tile">
            <span className="sm-stat__label">Hit Points</span>
            <div className="sm-hp">
              <NumberField
                className="sm-hp__current"
                aria-label="Steel defender current HP"
                value={current}
                min={0}
                max={block.maxHp}
                disabled={!canEdit}
                onCommit={(n) => write({ damage: block.maxHp - n }, "its HP")}
              />
              <span className="sm-hp__slash">/</span>
              <span className="sm-companion__max">{block.maxHp}</span>
            </div>
            <label className="sm-combat__inline">
              <span>Temp</span>
              <NumberField
                aria-label="Steel defender temp HP"
                value={companion.hpTemp}
                min={0}
                max={999}
                disabled={!canEdit}
                onCommit={(n) => write({ hpTemp: n }, "its temp HP")}
              />
            </label>
            {canEdit && (
              <div className="sm-hp__adjust">
                <input
                  type="number"
                  min={1}
                  aria-label="Steel defender damage or healing amount"
                  placeholder="amt"
                  value={hpDelta}
                  onChange={(e) => setHpDelta(e.target.value)}
                />
                <button
                  type="button"
                  className="ch-button ch-button--danger"
                  onClick={() => applyHp(-1)}
                >
                  Damage
                </button>
                <button type="button" className="ch-button" onClick={() => applyHp(1)}>
                  Heal
                </button>
              </div>
            )}
            {current === 0 && (
              <span className="sm-combat__note sm-combat__note--warn">
                Destroyed. Within the hour, an action with smith's tools and a spell slot
                revives it at full HP; after a long rest you can build a new one.
              </span>
            )}
          </div>
        </div>

        <ul className="sm-companion__scores">
          {ABILITIES.map((a) => (
            <li key={a}>
              <span className="sm-race-facts__label">{a}</span>
              {block.scores[a]} ({formatModifier(abilityModifier(block.scores[a]))})
            </li>
          ))}
        </ul>

        <ul className="sm-race-facts">
          <Fact label="Speed">{block.speed} ft</Fact>
          <Fact label="Hit dice">{block.hitDice}</Fact>
          <Fact label="Saves">
            {block.saves.map((s) => `${s.ability.toUpperCase()} ${formatModifier(s.bonus)}`).join(", ")}
          </Fact>
          <Fact label="Skills">
            {block.skills.map((s) => `${s.name} ${formatModifier(s.bonus)}`).join(", ")}
          </Fact>
          <Fact label="Senses">
            {block.senses}, passive Perception {block.passivePerception}
          </Fact>
          <Fact label="Immune">{block.damageImmunities}</Fact>
          <Fact label="Conditions">{block.conditionImmunities}</Fact>
          <Fact label="Languages">{block.languages}</Fact>
        </ul>

        <ul className="sm-features">
          {block.actions.map((a) => (
            <li key={a.name} className="sm-feature">
              <div className="sm-feature__head">
                <span className="sm-feature__name">{a.name}</span>
                <span className="sm-feature__level">{a.timing}</span>
              </div>
              <p className="sm-feature__text">{a.detail}</p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <li>
      <span className="sm-race-facts__label">{label}</span>
      {children}
    </li>
  );
}

/**
 * NumberField's shape for text: saves on blur or Enter, Escape reverts, and
 * the draft re-syncs from `value` while the field isn't being edited.
 */
function TextField({
  value,
  onCommit,
  disabled,
  placeholder,
  maxLength,
}: {
  value: string;
  onCommit: (text: string) => void;
  disabled?: boolean;
  placeholder?: string;
  maxLength?: number;
}) {
  const [draft, setDraft] = useState(value);
  const [editing, setEditing] = useState(false);
  const cancelled = useRef(false);

  useEffect(() => {
    if (!editing) setDraft(value);
  }, [value, editing]);

  const commit = () => {
    setEditing(false);
    if (cancelled.current) {
      cancelled.current = false;
      setDraft(value);
      return;
    }
    if (draft.trim() !== value.trim()) onCommit(draft);
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
      type="text"
      value={draft}
      disabled={disabled}
      placeholder={placeholder}
      maxLength={maxLength}
      onFocus={() => setEditing(true)}
      onChange={(e) => setDraft(e.target.value)}
      onBlur={commit}
      onKeyDown={onKeyDown}
    />
  );
}
