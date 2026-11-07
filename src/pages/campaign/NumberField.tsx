import { KeyboardEvent, useEffect, useRef, useState } from "react";

/**
 * A number input that saves on blur or Enter rather than on every keystroke:
 * typing "15" would otherwise write 1 and then 15, and a cleared field would
 * try to save nothing. Escape reverts. The draft re-syncs from `value` when
 * the server's number changes (another device, the DM) while the field isn't
 * being edited.
 */
export function NumberField({
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
