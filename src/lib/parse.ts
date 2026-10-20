/**
 * Throwing parsers for values crossing the DB boundary, shared by the services
 * that map rows into app types.
 *
 * Generated row types catch a renamed column. They don't catch a nullable
 * column the app treats as required, or a `text` column the app narrows to a
 * union — real runtime values the type alone won't stop.
 *
 * `subject` leads the error: callers pass something identifying the row
 * ("Item <uuid>"), since a bare field name doesn't say which row was bad.
 */

// `== null` (loose) on purpose — catches undefined as well as null.
export function requireField<T>(
  value: T | null | undefined,
  field: string,
  subject: string,
): T {
  if (value == null) throw new Error(`${subject}: missing ${field}`);
  return value;
}

// Returns the narrowed value rather than narrowing in place, hence "parse" not
// "assert" — TS assertion functions return void, which this does not.
// The cast is on `allowed`, not `value`: widening readonly T[] to readonly
// unknown[] is always sound, so it sits on something known-true while the
// actual check stays honest. `value` is unknown because the generator types an
// array of a domain as unknown[] (083's fighting_style_options); only a string
// in the list can pass, so nothing else needs checking first.
export function parseOneOf<T extends string>(
  value: unknown,
  allowed: readonly T[],
  field: string,
  subject: string,
): T {
  if (!(allowed as readonly unknown[]).includes(value)) {
    throw new Error(`${subject}: invalid ${field} "${value}"`);
  }
  return value as T;
}
