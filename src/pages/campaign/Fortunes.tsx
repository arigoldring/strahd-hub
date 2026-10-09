import { SubmitEvent, useEffect, useState } from "react";
import { useCampaign } from "../../components/CampaignLayout";
import { usePlayerPreview } from "../../components/PlayerPreviewContext";
import { useFortunes } from "../../hooks/useFortunes";
import { Fortune } from "../../services/fortunes";
import { errorMessage } from "../../lib/errors";
import "./fortunes.css";

const NUMERALS = ["I", "II", "III"];

/**
 * Madam Eva's reading: three fortunes, one per artifact.
 *
 * No route guard. A player who types the URL before the reading gets the
 * empty state, because RLS (065) gave them no rows -- there is nothing on this
 * page a redirect would be protecting.
 */
export function Fortunes() {
  const campaign = useCampaign();
  const { previewing } = usePlayerPreview();
  // The same weaker question NPC and Recaps ask: preview puts the controls
  // away, never the permission.
  const showDmUi = campaign.isDm && !previewing;
  const {
    data: fortunes = [],
    isLoading,
    error,
    setRevealed,
    setRevealedError,
    revealPending,
    setFound,
    setFoundError,
    saveLines,
  } = useFortunes(campaign.id, { asPlayer: previewing });

  // One open editor at a time, by id -- Recaps' shape.
  const [editingId, setEditingId] = useState<string | null>(null);

  // An editor opened before switching to player view must not ride through
  // it as a DM control on the page meant to show what a player sees.
  useEffect(() => {
    setEditingId(null);
  }, [previewing]);

  if (isLoading) return <p>Loading...</p>;
  if (error) return <p>{error.message}</p>;

  // The DM gets all three rows whatever their state, so this is the flag, not
  // the length. A player only ever has rows when it's true.
  const revealed = fortunes.some((f) => f.isRevealed);

  return (
    <div className="fortunes">
      <h1 className="fortunes__heading">Fortunes</h1>
      <p className="fortunes__intro">
        As read by Madam Eva at Tser Pool.
      </p>

      {showDmUi && (
        <div className="fortunes__dm">
          <span
            className={`fortunes__status${revealed ? " fortunes__status--live" : ""}`}
          >
            {revealed ? "Revealed to players" : "Hidden from players"}
          </span>
          <button
            onClick={() => setRevealed(!revealed)}
            disabled={revealPending}
          >
            {revealed ? "Hide the reading" : "Reveal the reading"}
          </button>
          {setRevealedError && (
            <p className="fortunes__error">{setRevealedError.message}</p>
          )}
          {setFoundError && (
            <p className="fortunes__error">{setFoundError.message}</p>
          )}
        </div>
      )}

      {fortunes.length === 0 ? (
        <p className="fortunes__empty">
          Madam Eva has not yet read the cards for you.
        </p>
      ) : (
        <div className="fortunes__spread">
          {fortunes.map((fortune) => (
            <FortuneCard
              key={fortune.id}
              fortune={fortune}
              showDmUi={showDmUi}
              isEditing={editingId === fortune.id}
              onEdit={() => setEditingId(fortune.id)}
              onStopEditing={() => setEditingId(null)}
              onSave={(lines) => saveLines({ id: fortune.id, lines })}
              onFound={(isFound) => setFound({ id: fortune.id, isFound })}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function FortuneCard({
  fortune,
  showDmUi,
  isEditing,
  onEdit,
  onStopEditing,
  onSave,
  onFound,
}: {
  fortune: Fortune;
  showDmUi: boolean;
  isEditing: boolean;
  onEdit: () => void;
  onStopEditing: () => void;
  onSave: (lines: string[]) => Promise<unknown>;
  onFound: (isFound: boolean) => void;
}) {
  return (
    <article className={`fortune${fortune.isFound ? " is-found" : ""}`}>
      <header className="fortune__head">
        <span className="fortune__numeral">
          {NUMERALS[fortune.card - 1] ?? fortune.card}
        </span>
        <h2 className="fortune__title">{fortune.title}</h2>
        {/* The DM's checkbox stands in for the badge, so it isn't shown twice. */}
        {fortune.isFound && !showDmUi && (
          <span className="fortune__found">Found</span>
        )}
      </header>

      {isEditing ? (
        // key: a fresh draft per card, so one card's text can't carry over.
        <FortuneEditor
          key={fortune.id}
          fortune={fortune}
          onSave={onSave}
          onClose={onStopEditing}
        />
      ) : (
        <blockquote className="fortune__lines">
          {fortune.lines.map((line, i) => (
            <p key={i}>“{line}”</p>
          ))}
        </blockquote>
      )}

      {showDmUi && !isEditing && (
        <div className="fortune__dm">
          <label className="fortune__check">
            <input
              type="checkbox"
              checked={fortune.isFound}
              onChange={(e) => onFound(e.target.checked)}
            />
            Found
          </label>
          <button className="fortune__edit" onClick={onEdit}>
            Edit
          </button>
        </div>
      )}
    </article>
  );
}

/**
 * The text only -- the title is pinned in the database (065), so the form
 * doesn't offer it. One textarea, one spoken line per line of it: the array
 * becomes newlines on the way in and splits back on the way out. Blank lines
 * are dropped by the service, so a stray empty line between two isn't saved.
 */
function FortuneEditor({
  fortune,
  onSave,
  onClose,
}: {
  fortune: Fortune;
  onSave: (lines: string[]) => Promise<unknown>;
  onClose: () => void;
}) {
  const [draft, setDraft] = useState(fortune.lines.join("\n"));
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  async function handleSubmit(e: SubmitEvent<HTMLFormElement>) {
    e.preventDefault();
    setSaving(true);
    setSaveError(null);
    try {
      await onSave(draft.split("\n"));
      onClose();
    } catch (err) {
      console.error("Problem saving fortune:", err);
      // Stays open holding the draft, so nothing typed is lost.
      setSaveError(errorMessage(err, "Problem saving fortune"));
      setSaving(false);
    }
  }

  return (
    <form className="fortune__editor" onSubmit={handleSubmit}>
      <label className="fortune__editor-label" htmlFor={`fortune-${fortune.id}`}>
        One line per line. Quotation marks are added for you.
      </label>
      <textarea
        id={`fortune-${fortune.id}`}
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        rows={10}
        disabled={saving}
      />
      {saveError && <p className="fortunes__error">{saveError}</p>}
      <div className="fortune__editor-actions">
        <button type="submit" disabled={saving}>
          {saving ? "Saving..." : "Save"}
        </button>
        <button type="button" onClick={onClose} disabled={saving}>
          Cancel
        </button>
      </div>
    </form>
  );
}
