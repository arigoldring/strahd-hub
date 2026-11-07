import { useState } from "react";
import { Band } from "./Character";
import { useCharacterResources } from "../../hooks/useCharacterResources";
import { errorMessage } from "../../lib/errors";
import { keysClearedByRest, type ResourceRecharge } from "../../data/rules";

/** One counter as the sheet shows it, its maximum already derived. */
export interface SheetCounter {
  /** character_resource_uses.resource_key (153). */
  key: string;
  name: string;
  /** What grants it ("Psionic Power"), shown when it differs from the name. */
  source: string;
  max: number;
  recharge: ResourceRecharge;
}

// Above this many uses a row of pips stops being readable on a phone (ki at
// 20, Lay on Hands' pool of 100), so the counter becomes an amount field.
const MAX_PIPS = 10;

const RECHARGE_LABELS: Record<ResourceRecharge, string> = {
  short: "Short rest",
  long: "Long rest",
};

/**
 * The Resources band: every use counter the character has, and the two rest
 * buttons. A filled pip is a spent use. Tapping an empty pip spends one;
 * tapping a filled one gives one back, so a misclick is one more tap to undo.
 */
export function SheetResources({
  characterId,
  counters,
  canEdit,
}: {
  characterId: string;
  counters: SheetCounter[];
  canEdit: boolean;
}) {
  const { uses = {}, isLoading, error, spend, rest } = useCharacterResources(characterId);
  const [saveError, setSaveError] = useState<string | null>(null);

  const run = (action: Promise<unknown>, what: string) => {
    setSaveError(null);
    action.catch((err) => setSaveError(errorMessage(err, `Couldn't save ${what}`)));
  };
  const change = (c: SheetCounter, delta: number) =>
    run(spend({ key: c.key, delta, cap: c.max }), c.name);

  const takeRest = (kind: ResourceRecharge) => {
    const label = kind === "short" ? "short rest" : "long rest";
    const what =
      kind === "short" ? "every short-rest counter" : "every counter";
    if (!window.confirm(`Take a ${label}? This refills ${what}.`)) return;
    // A long rest clears every stored row, including any whose counter the
    // sheet no longer shows (a feature lost to a level drop).
    run(rest(kind === "long" ? "all" : keysClearedByRest(counters, "short")), `the ${label}`);
  };

  return (
    <section>
      <Band label="Resources">
        {canEdit && (
          <div className="sm-rest">
            <button type="button" className="ch-button" onClick={() => takeRest("short")}>
              Short Rest
            </button>
            <button type="button" className="ch-button" onClick={() => takeRest("long")}>
              Long Rest
            </button>
          </div>
        )}
      </Band>
      <div className="ch-body">
        {saveError && <p className="ch-error">{saveError}</p>}
        {error ? (
          <p className="ch-error">{error.message}</p>
        ) : isLoading ? (
          <p className="ch-empty">Counting...</p>
        ) : counters.length === 0 ? (
          <p className="ch-empty">Nothing to count for this class and level yet.</p>
        ) : (
          <ul className="sm-resources">
            {counters.map((c) => (
              <CounterRow
                key={c.key}
                counter={c}
                // A stored count above a lowered maximum shows as full.
                used={Math.min(uses[c.key] ?? 0, c.max)}
                canEdit={canEdit}
                change={(delta) => change(c, delta)}
              />
            ))}
          </ul>
        )}
      </div>
    </section>
  );
}

function CounterRow({
  counter: c,
  used,
  canEdit,
  change,
}: {
  counter: SheetCounter;
  used: number;
  canEdit: boolean;
  change: (delta: number) => void;
}) {
  const [amount, setAmount] = useState("");
  const left = c.max - used;
  const applyAmount = (sign: 1 | -1) => {
    const n = Number.parseInt(amount, 10);
    if (!Number.isNaN(n) && n > 0) {
      change(sign * n);
      setAmount("");
    }
  };

  return (
    <li className="sm-resource">
      <div className="sm-resource__head">
        <span className="sm-resource__name">{c.name}</span>
        {c.source !== c.name && <span className="sm-resource__source">{c.source}</span>}
        <span className={`sm-resource__recharge sm-resource__recharge--${c.recharge}`}>
          {RECHARGE_LABELS[c.recharge]}
        </span>
      </div>
      {c.max <= MAX_PIPS ? (
        <div className="sm-resource__pips" role="group" aria-label={`${c.name}: ${left} of ${c.max} left`}>
          {Array.from({ length: c.max }, (_, i) => {
            const spent = i < used;
            return (
              <button
                key={i}
                type="button"
                className={`sm-pip sm-resource__pip${spent ? " sm-pip--1" : ""}`}
                aria-label={spent ? `Give back a use of ${c.name}` : `Use ${c.name}`}
                title={spent ? "Spent: tap to give it back" : "Tap to use"}
                disabled={!canEdit}
                onClick={() => change(spent ? -1 : 1)}
              />
            );
          })}
          <span className="sm-resource__count">
            {left}/{c.max}
          </span>
        </div>
      ) : (
        <div className="sm-resource__pool">
          <span className="sm-resource__count">
            {left} left of {c.max}
          </span>
          {canEdit && (
            <>
              <input
                type="number"
                min={1}
                aria-label={`${c.name}: amount`}
                placeholder="amt"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
              />
              <button type="button" className="ch-button" onClick={() => applyAmount(1)}>
                Use
              </button>
              <button type="button" className="ch-button" onClick={() => applyAmount(-1)}>
                Restore
              </button>
            </>
          )}
        </div>
      )}
    </li>
  );
}
