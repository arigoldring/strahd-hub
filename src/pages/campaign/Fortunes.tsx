import { SubmitEvent, useEffect, useState } from "react";
import { useCampaign } from "../../components/CampaignLayout";
import { useDmView } from "../../hooks/useDmView";
import { useFortunes } from "../../hooks/useFortunes";
import { Fortune, visionText } from "../../services/fortunes";
import { errorMessage } from "../../lib/errors";
import "./fortunes.css";

const NUMERALS = ["I", "II", "III", "IV", "V"];

/**
 * Madam Eva's reading: three artifacts, then two companions (127).
 *
 * No route guard. A player who types the URL before the reading gets the
 * empty state, because RLS (065) gave them no rows -- there is nothing on this
 * page a redirect would be protecting.
 */
export function Fortunes() {
  const campaign = useCampaign();
  // The same weaker question NPC and Recaps ask: preview puts the controls
  // away, never the permission.
  const { showDmUi, asPlayer } = useDmView();
  const {
    data: fortunes = [],
    isLoading,
    error,
    setRevealed,
    setRevealedError,
    revealPending,
    setFound,
    setFoundError,
    saveStanzas,
  } = useFortunes(campaign.id, { asPlayer });

  // One open editor at a time, by id -- Recaps' shape.
  const [editingId, setEditingId] = useState<string | null>(null);

  // An editor opened before switching to player view must not ride through
  // it as a DM control on the page meant to show what a player sees.
  useEffect(() => {
    setEditingId(null);
  }, [showDmUi]);

  if (isLoading) return <p>Loading...</p>;
  if (error) return <p>{error.message}</p>;

  // The DM gets every row whatever their state, so this is the flag, not
  // the length. A player only ever has rows when it's true.
  const revealed = fortunes.some((f) => f.isRevealed);

  return (
    <div className="fortunes">
      <h1 className="fortunes__heading">Fortunes</h1>
      <p className="fortunes__intro">
        As read by Madam Eva.
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
              onSave={(stanzas) => saveStanzas({ id: fortune.id, stanzas })}
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
  onSave: (stanzas: string[]) => Promise<unknown>;
  onFound: (isFound: boolean) => void;
}) {
  // A companion's fortune has nothing to find, so neither the DM's checkbox
  // nor the badge appears on it. 127's CHECK refuses the write anyway.
  const findable = fortune.isArtifact;

  return (
    <article className={`fortune${fortune.isFound ? " is-found" : ""}`}>
      <header className="fortune__head">
        <span className="fortune__numeral">
          {NUMERALS[fortune.card - 1] ?? fortune.card}
        </span>
        <h2 className="fortune__title">{fortune.title}</h2>
        {/* The DM's checkbox stands in for the badge, so it isn't shown twice. */}
        {findable && fortune.isFound && !showDmUi && (
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
          {/* One <p> per stanza; pre-line in the CSS breaks its verse lines.
              A [bracketed] stanza is a vision note, set as narration. */}
          {fortune.stanzas.map((stanza, i) => {
            const vision = visionText(stanza);
            return vision === null ? (
              <p key={i}>{stanza}</p>
            ) : (
              <p key={i} className="fortune__vision">
                {vision}
              </p>
            );
          })}
        </blockquote>
      )}

      {showDmUi && !isEditing && (
        <div className="fortune__dm">
          {findable ? (
            <label className="fortune__check">
              <input
                type="checkbox"
                checked={fortune.isFound}
                onChange={(e) => onFound(e.target.checked)}
              />
              Found
            </label>
          ) : (
            // Holds the Edit button at the right, where space-between puts it.
            <span />
          )}
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
 * doesn't offer it. One textarea: a verse line per line, a blank line between
 * stanzas. The stanzas are joined with a blank line on the way in and split on
 * blank lines (whitespace-only counts) on the way out; the service trims each
 * line and drops empty stanzas, so extra blank lines aren't saved.
 */
function FortuneEditor({
  fortune,
  onSave,
  onClose,
}: {
  fortune: Fortune;
  onSave: (stanzas: string[]) => Promise<unknown>;
  onClose: () => void;
}) {
  const [draft, setDraft] = useState(fortune.stanzas.join("\n\n"));
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  async function handleSubmit(e: SubmitEvent<HTMLFormElement>) {
    e.preventDefault();
    setSaving(true);
    setSaveError(null);
    try {
      await onSave(draft.split(/\n\s*\n/));
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
        One line per line; a blank line between stanzas. Put a vision note in
        [square brackets].
      </label>
      <textarea
        id={`fortune-${fortune.id}`}
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        rows={14}
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
