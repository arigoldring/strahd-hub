import { KeyboardEvent, SubmitEvent, useEffect, useRef, useState } from "react";
import { useCampaign } from "../../components/CampaignLayout";
import { usePlayerPreview } from "../../components/PlayerPreviewContext";
import { useAuth } from "../../services/AuthContext";
import { useParty } from "../../hooks/useParty";
import {
  useEncounter,
  useMonsterStats,
  usePcCombatInfo,
  type PcCombatInfo,
} from "../../hooks/useEncounter";
import { useCharacterSheet } from "../../hooks/useCharacterSheet";
import { useCharacterCompanions } from "../../hooks/useCharacterCompanions";
import {
  formatModifier,
  nextTurn,
  previousTurn,
  rollInitiative,
  turnOrder,
  type TurnEntry,
} from "../../data/rules";
import { COMPANION_DEFAULT_NAMES } from "../../services/companions";
import type {
  Combatant,
  MonsterStats,
  MonsterStatsPatch,
  NewMonsters,
} from "../../services/encounters";
import { errorMessage } from "../../lib/errors";
import { NumberField } from "./NumberField";
import "./character.css";
import "./combat.css";

/**
 * The initiative tracker (171-172): one live fight per campaign.
 *
 * One page for everyone. The DM gets the controls; a player sees the order,
 * the turn, each monster's Bloodied/Down (never its numbers, which RLS
 * doesn't send them) and an initiative box on their own PC's row. The order
 * is sorted on every screen by rules.ts's turnOrder, and 172 keeps every
 * screen's copy live.
 *
 * Gating here is showDmUi (Fortunes' rule): player preview puts the
 * controls away. Whether a write is allowed is the database's answer, not
 * this page's.
 */
export function Combat() {
  const campaign = useCampaign();
  const { previewing } = usePlayerPreview();
  const { profile } = useAuth();
  const showDmUi = campaign.isDm && !previewing;

  const { data: party = [], isLoading: partyLoading, error: partyError } = useParty(campaign.id);
  const fight = useEncounter(campaign.id);
  const { encounter } = fight;
  // Every PC in the campaign, not only those in the fight: Start needs to
  // know who has a defender, and the hooks can't depend on the fight.
  const pcInfo = usePcCombatInfo(
    campaign.id,
    party.map((c) => c.id),
  );
  const monsters = useMonsterStats(campaign.id, encounter?.id ?? null, showDmUi);

  // One error line for the page's controls, the sheet's shape.
  const [actionError, setActionError] = useState<string | null>(null);
  const run = (action: Promise<unknown>, what: string) => {
    setActionError(null);
    action.catch((err) => setActionError(errorMessage(err, `Couldn't ${what}`)));
  };

  if (fight.isLoading || partyLoading) return <p>Gathering the combatants...</p>;
  if (fight.error || partyError) {
    return <p className="ch-error">{(fight.error ?? partyError)!.message}</p>;
  }

  const startingPcs = (ids: string[]) =>
    ids.map((id) => ({
      characterId: id,
      hasDefender: pcInfo.info.get(id)?.defenderMaxHp != null,
    }));

  if (!encounter) {
    return (
      <div className="ch combat">
        <h1 className="combat__heading">Combat</h1>
        {actionError && <p className="ch-error">{actionError}</p>}
        <p className="ch-empty">No fight is running.</p>
        {showDmUi && (
          <button
            type="button"
            className="ch-button"
            disabled={pcInfo.isLoading}
            onClick={() =>
              run(
                fight.start(startingPcs(party.map((c) => c.id))),
                "start the fight",
              )
            }
          >
            Start a fight
          </button>
        )}
      </div>
    );
  }

  const nameOf = new Map(party.map((c) => [c.id, c.name]));
  const statsOf = new Map((monsters.stats ?? []).map((s) => [s.combatantId, s]));
  const entries: (TurnEntry & { combatant: Combatant })[] = encounter.combatants.map((c) => ({
    id: c.id,
    kind: c.kind,
    characterId: c.characterId,
    name:
      c.kind === "monster"
        ? (c.name ?? "Monster")
        : c.kind === "companion"
          ? COMPANION_DEFAULT_NAMES.steel_defender
          : (nameOf.get(c.characterId ?? "") ?? "Unknown"),
    initiative: c.initiative,
    // A PC's DEX is on their sheet; 10 until it loads, which can only move
    // them within a tie.
    dex: c.kind === "monster" ? (c.dex ?? 10) : (pcInfo.info.get(c.characterId ?? "")?.dex ?? 10),
    combatant: c,
  }));
  const order = turnOrder(entries);
  const state = { turnId: encounter.turnCombatantId, round: encounter.round };
  const current = order.find((e) => e.id === encounter.turnCombatantId) ?? null;
  const ownPcIds = new Set(party.filter((c) => c.userId === profile?.id).map((c) => c.id));
  const yourTurn =
    current !== null && current.characterId !== null && ownPcIds.has(current.characterId);

  const bonusFor = (e: TurnEntry): number | null =>
    e.kind === "pc"
      ? (pcInfo.info.get(e.characterId ?? "")?.initiativeBonus ?? null)
      : e.kind === "monster"
        ? (statsOf.get(e.id)?.initBonus ?? null)
        : null;

  const rollFor = (targets: TurnEntry[]) => {
    const rolls = targets.flatMap((e) => {
      const bonus = bonusFor(e);
      return bonus === null ? [] : [{ combatantId: e.id, initiative: rollInitiative(bonus).total }];
    });
    if (rolls.length > 0) run(fight.setInitiatives(rolls), "roll initiative");
  };
  const rollable = order.filter((e) => e.kind !== "companion");
  const rollEveryone = () => {
    const anyRolled = rollable.some((e) => e.initiative !== null);
    if (anyRolled && !window.confirm("Reroll everyone, replacing the rolls already in?")) return;
    rollFor(rollable);
  };

  const advance = (to: { turnId: string | null; round: number }) =>
    run(fight.setTurn({ encounterId: encounter.id, ...to }), "change the turn");

  // Removing the combatant whose turn it is hands the turn on first, so the
  // fight doesn't stall on 171's set-null.
  const remove = (id: string) => {
    const go = async () => {
      if (encounter.turnCombatantId === id) {
        const next = nextTurn(order, state);
        await fight.setTurn({
          encounterId: encounter.id,
          turnId: next.turnId === id ? null : next.turnId,
          round: next.round,
        });
      }
      await fight.remove(id);
    };
    run(go(), "remove that combatant");
  };

  const missingPcs = party.filter(
    (c) => !encounter.combatants.some((x) => x.kind === "pc" && x.characterId === c.id),
  );

  return (
    <div className="ch combat">
      <h1 className="combat__heading">Combat</h1>

      <div className="combat__bar">
        <span className="combat__round">Round {encounter.round}</span>
        <span className="combat__turn">
          {current ? (
            <>
              <span className="combat__turn-label">Turn</span> {current.name}
            </>
          ) : (
            "Not started"
          )}
        </span>
        {showDmUi && (
          <div className="combat__controls">
            <button
              type="button"
              className="ch-button"
              disabled={order.length === 0 || (encounter.round <= 1 && order[0]?.id === current?.id)}
              onClick={() => advance(previousTurn(order, state))}
            >
              Back
            </button>
            <button
              type="button"
              className="ch-button combat__next"
              disabled={order.length === 0}
              onClick={() => advance(nextTurn(order, state))}
            >
              {current ? "Next turn" : "Begin"}
            </button>
          </div>
        )}
      </div>

      {yourTurn && <p className="combat__your-turn">It's your turn.</p>}
      {actionError && <p className="ch-error">{actionError}</p>}

      {showDmUi && (
        <div className="combat__dm">
          <button
            type="button"
            className="ch-button"
            disabled={pcInfo.isLoading}
            onClick={() => rollFor(rollable.filter((e) => e.initiative === null))}
          >
            Roll the unrolled
          </button>
          <button
            type="button"
            className="ch-button"
            disabled={pcInfo.isLoading}
            onClick={rollEveryone}
          >
            Roll everyone
          </button>
          {missingPcs.map((c) => (
            <button
              key={c.id}
              type="button"
              className="ch-button"
              onClick={() =>
                run(
                  fight.addPcs({ encounterId: encounter.id, pcs: startingPcs([c.id]) }),
                  `add ${c.name}`,
                )
              }
            >
              + {c.name}
            </button>
          ))}
          <button
            type="button"
            className="ch-button ch-button--danger combat__end"
            onClick={() => {
              if (window.confirm("End the fight? The order and the monsters are deleted.")) {
                run(fight.end(encounter.id), "end the fight");
              }
            }}
          >
            End fight
          </button>
        </div>
      )}

      {order.length === 0 ? (
        <p className="ch-empty">Nobody is in this fight yet.</p>
      ) : (
        <ol className="combat__order">
          {order.map((e) => (
            <CombatantRow
              key={e.id}
              entry={e}
              combatant={e.combatant}
              isTurn={e.id === encounter.turnCombatantId}
              showDmUi={showDmUi}
              isOwn={e.characterId !== null && ownPcIds.has(e.characterId)}
              pc={e.characterId ? pcInfo.info.get(e.characterId) : undefined}
              stats={statsOf.get(e.id)}
              bonus={bonusFor(e)}
              setInitiative={(n) =>
                run(fight.update({ combatantId: e.id, patch: { initiative: n } }), "save initiative")
              }
              adjustMonster={(delta) =>
                run(monsters.adjustHp({ combatantId: e.id, delta }), "change its HP")
              }
              updateMonster={(current, patch) =>
                run(monsters.update({ current, patch }), "save the monster")
              }
              remove={() => remove(e.id)}
              report={(action, what) => run(action, what)}
            />
          ))}
        </ol>
      )}

      {showDmUi && (
        <AddMonsters
          onAdd={(m) => run(fight.addMonsters({ encounterId: encounter.id, monsters: m }), "add monsters")}
        />
      )}
    </div>
  );
}

function CombatantRow({
  entry,
  combatant,
  isTurn,
  showDmUi,
  isOwn,
  pc,
  stats,
  bonus,
  setInitiative,
  adjustMonster,
  updateMonster,
  remove,
  report,
}: {
  entry: TurnEntry;
  combatant: Combatant;
  isTurn: boolean;
  showDmUi: boolean;
  isOwn: boolean;
  pc: PcCombatInfo | undefined;
  stats: MonsterStats | undefined;
  bonus: number | null;
  setInitiative: (n: number | null) => void;
  adjustMonster: (delta: number) => void;
  updateMonster: (current: MonsterStats, patch: MonsterStatsPatch) => void;
  remove: () => void;
  report: (action: Promise<unknown>, what: string) => void;
}) {
  const isCompanion = entry.kind === "companion";
  const canSetInitiative = !isCompanion && (showDmUi || (entry.kind === "pc" && isOwn));
  const down =
    combatant.status === "down" || (entry.kind === "pc" && pc !== undefined && pc.hpCurrent === 0);

  const className = [
    "combat__row",
    isTurn && "combat__row--turn",
    isCompanion && "combat__row--companion",
    down && "combat__row--down",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <li className={className} aria-current={isTurn ? "true" : undefined}>
      <div className="combat__init">
        {isCompanion ? (
          <span className="combat__with" title="Acts right after its artificer">
            ↳
          </span>
        ) : canSetInitiative ? (
          <InitiativeField value={combatant.initiative} onCommit={setInitiative} />
        ) : (
          <span className="combat__init-value">{combatant.initiative ?? "—"}</span>
        )}
      </div>

      <div className="combat__who">
        <span className="combat__name">{entry.name}</span>
        <span className="combat__meta">
          {entry.kind === "monster" ? "Monster" : isCompanion ? "Companion" : "PC"}
          {showDmUi && bonus !== null && ` · init ${formatModifier(bonus)}`}
          {/* Label only: the DEX is still on the public row, for turnOrder. */}
          {showDmUi && entry.kind === "monster" && ` · DEX ${entry.dex}`}
        </span>
      </div>

      <div className="combat__hp">
        {entry.kind === "pc" && entry.characterId && (
          <PcHp characterId={entry.characterId} pc={pc} canEdit={showDmUi || isOwn} report={report} />
        )}
        {isCompanion && entry.characterId && (
          <DefenderHp
            characterId={entry.characterId}
            maxHp={pc?.defenderMaxHp ?? null}
            canEdit={showDmUi || isOwn}
            report={report}
          />
        )}
        {entry.kind === "monster" &&
          (showDmUi && stats ? (
            <MonsterHp stats={stats} adjust={adjustMonster} update={updateMonster} />
          ) : (
            <StatusBadge status={combatant.status} />
          ))}
      </div>

      {showDmUi && (
        <div className="combat__row-actions">
          {!isCompanion && (
            <button
              type="button"
              className="ch-button"
              disabled={bonus === null}
              onClick={() => bonus !== null && setInitiative(rollInitiative(bonus).total)}
            >
              Roll
            </button>
          )}
          {!isCompanion && (
            <button type="button" className="ch-button ch-button--danger" onClick={remove}>
              Remove
            </button>
          )}
        </div>
      )}
    </li>
  );
}

/**
 * A PC's HP, the sheet's own number: the same cache entry, and the same
 * adjust_character_hp write, so a hit here is a hit on the sheet. The owner
 * or the DM may apply it, 056's line.
 */
function PcHp({
  characterId,
  pc,
  canEdit,
  report,
}: {
  characterId: string;
  pc: PcCombatInfo | undefined;
  canEdit: boolean;
  report: (action: Promise<unknown>, what: string) => void;
}) {
  const { adjustHp } = useCharacterSheet(characterId);
  if (!pc) return <span className="combat__hp-value">…</span>;
  return (
    <>
      <span className="combat__hp-value">
        {pc.hpCurrent}/{pc.hpMax}
        {pc.hpTemp > 0 && <span className="combat__temp"> +{pc.hpTemp}</span>}
      </span>
      {canEdit && <HpAdjust onApply={(d) => report(adjustHp(d), "change their HP")} />}
    </>
  );
}

/**
 * The steel defender's HP through 167's adjust_companion_hp, capped at the
 * maximum derived from the artificer's sheet. No row is a full-health
 * defender (167), so the damage defaults to 0.
 */
function DefenderHp({
  characterId,
  maxHp,
  canEdit,
  report,
}: {
  characterId: string;
  maxHp: number | null;
  canEdit: boolean;
  report: (action: Promise<unknown>, what: string) => void;
}) {
  const { companions, isLoading, adjustHp } = useCharacterCompanions(characterId);
  if (maxHp === null || isLoading) return <span className="combat__hp-value">…</span>;
  const stored = companions?.find((c) => c.kind === "steel_defender");
  const current = maxHp - Math.min(stored?.damage ?? 0, maxHp);
  return (
    <>
      <span className="combat__hp-value">
        {current}/{maxHp}
        {(stored?.hpTemp ?? 0) > 0 && <span className="combat__temp"> +{stored!.hpTemp}</span>}
      </span>
      {canEdit && (
        <HpAdjust
          onApply={(delta) =>
            report(adjustHp({ kind: "steel_defender", delta, cap: maxHp }), "change its HP")
          }
        />
      )}
    </>
  );
}

/** The DM's view of a monster: the numbers, typed or applied. */
function MonsterHp({
  stats,
  adjust,
  update,
}: {
  stats: MonsterStats;
  adjust: (delta: number) => void;
  update: (current: MonsterStats, patch: MonsterStatsPatch) => void;
}) {
  return (
    <>
      <span className="combat__hp-value">
        <NumberField
          className="combat__num"
          aria-label="Current HP"
          value={stats.hpCurrent}
          min={0}
          max={stats.hpMax}
          onCommit={(n) => update(stats, { hpCurrent: n })}
        />
        /
        <NumberField
          className="combat__num"
          aria-label="Max HP"
          value={stats.hpMax}
          min={1}
          max={9999}
          onCommit={(n) => update(stats, { hpMax: n })}
        />
        {stats.hpTemp > 0 && <span className="combat__temp"> +{stats.hpTemp}</span>}
      </span>
      {stats.ac !== null && <span className="combat__ac">AC {stats.ac}</span>}
      <HpAdjust onApply={adjust} />
    </>
  );
}

function StatusBadge({ status }: { status: Combatant["status"] }) {
  if (!status) return null;
  return (
    <span className={`combat__status combat__status--${status}`}>
      {status === "down" ? "Down" : "Bloodied"}
    </span>
  );
}

/** An amount, then Damage or Heal. The sheet's control, in one line. */
function HpAdjust({ onApply }: { onApply: (delta: number) => void }) {
  const [amount, setAmount] = useState("");
  const apply = (sign: 1 | -1) => {
    const n = Number.parseInt(amount, 10);
    if (!Number.isNaN(n) && n > 0) {
      onApply(sign * n);
      setAmount("");
    }
  };
  return (
    <span className="combat__adjust">
      <input
        type="number"
        min={1}
        aria-label="Damage or healing amount"
        placeholder="amt"
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") apply(-1);
        }}
      />
      <button type="button" className="ch-button ch-button--danger" onClick={() => apply(-1)}>
        Dmg
      </button>
      <button type="button" className="ch-button" onClick={() => apply(1)}>
        Heal
      </button>
    </span>
  );
}

/**
 * NumberField's commit-on-blur, but blank is a value: it clears the roll
 * (null), which NumberField would refuse. 171's CHECK is -10 to 99.
 */
function InitiativeField({
  value,
  onCommit,
}: {
  value: number | null;
  onCommit: (n: number | null) => void;
}) {
  const shown = value === null ? "" : String(value);
  const [draft, setDraft] = useState(shown);
  const [editing, setEditing] = useState(false);
  const cancelled = useRef(false);

  useEffect(() => {
    if (!editing) setDraft(shown);
  }, [shown, editing]);

  const commit = () => {
    setEditing(false);
    if (cancelled.current) {
      cancelled.current = false;
      setDraft(shown);
      return;
    }
    const trimmed = draft.trim();
    const n = trimmed === "" ? null : Number.parseInt(trimmed, 10);
    if (n !== null && Number.isNaN(n)) {
      setDraft(shown);
      return;
    }
    const clamped = n === null ? null : Math.min(99, Math.max(-10, n));
    setDraft(clamped === null ? "" : String(clamped));
    if (clamped !== value) onCommit(clamped);
  };

  return (
    <input
      type="number"
      className="combat__init-input"
      aria-label="Initiative"
      placeholder="—"
      value={draft}
      onFocus={() => setEditing(true)}
      onChange={(e) => setDraft(e.target.value)}
      onBlur={commit}
      onKeyDown={(e: KeyboardEvent<HTMLInputElement>) => {
        if (e.key === "Enter") e.currentTarget.blur();
        if (e.key === "Escape") {
          cancelled.current = true;
          e.currentTarget.blur();
        }
      }}
    />
  );
}

/**
 * The DM's form for monsters typed in at the table. Count numbers them
 * ("Zombie 1", "Zombie 2"); every copy gets the same stats.
 */
function AddMonsters({ onAdd }: { onAdd: (m: NewMonsters) => void }) {
  const [name, setName] = useState("");
  const [count, setCount] = useState("1");
  const [hp, setHp] = useState("");
  const [ac, setAc] = useState("");
  const [initBonus, setInitBonus] = useState("0");
  const [dex, setDex] = useState("10");

  const int = (s: string, fallback: number) => {
    const n = Number.parseInt(s, 10);
    return Number.isNaN(n) ? fallback : n;
  };
  const hpMax = int(hp, 0);
  const valid = name.trim() !== "" && hpMax >= 1;

  const submit = (e: SubmitEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!valid) return;
    onAdd({
      name: name.trim(),
      count: Math.min(20, Math.max(1, int(count, 1))),
      hpMax: Math.min(9999, hpMax),
      ac: ac.trim() === "" ? null : Math.min(40, Math.max(0, int(ac, 10))),
      initBonus: Math.min(20, Math.max(-10, int(initBonus, 0))),
      dex: Math.min(30, Math.max(1, int(dex, 10))),
    });
    setName("");
    setCount("1");
  };

  return (
    <form className="combat__add" onSubmit={submit}>
      <h2 className="combat__add-title">Add monsters</h2>
      <label>
        <span>Name</span>
        <input type="text" maxLength={36} value={name} onChange={(e) => setName(e.target.value)} />
      </label>
      <label>
        <span>How many</span>
        <input type="number" min={1} max={20} value={count} onChange={(e) => setCount(e.target.value)} />
      </label>
      <label>
        <span>HP</span>
        <input type="number" min={1} value={hp} onChange={(e) => setHp(e.target.value)} />
      </label>
      <label>
        <span>AC</span>
        <input type="number" min={0} max={40} value={ac} onChange={(e) => setAc(e.target.value)} />
      </label>
      <label>
        <span>Init bonus</span>
        <input
          type="number"
          min={-10}
          max={20}
          value={initBonus}
          onChange={(e) => setInitBonus(e.target.value)}
        />
      </label>
      <label>
        <span>DEX</span>
        <input type="number" min={1} max={30} value={dex} onChange={(e) => setDex(e.target.value)} />
      </label>
      <button type="submit" className="ch-button" disabled={!valid}>
        Add
      </button>
    </form>
  );
}
