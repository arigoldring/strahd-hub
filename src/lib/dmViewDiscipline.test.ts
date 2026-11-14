import { describe, expect, it } from "vitest";

/**
 * Player preview is only as good as the rule that every DM control reads
 * `showDmUi` (from useDmView) rather than bare `campaign.isDm`. A page that
 * forgets looks completely normal and leaks into preview silently, which is
 * how Home once kept its DM band and the nav kept New Item.
 *
 * So bare `.isDm` in pages and components fails this test unless the line,
 * or the one above it, carries a `dm-identity:` comment saying why this check
 * is about who is signed in rather than what preview should show. The
 * legitimate cases are few and stable: route guards (preview must not bounce
 * a DM off the page), the preview toggle (it has to survive its own effect),
 * the role badge, and dispatches where a DM has no player-side equivalent.
 *
 * This is a text scan, not a lint rule, because typescript-eslint does not
 * support TypeScript 7, so ESLint cannot parse this repo's .ts/.tsx yet. It
 * strips comments first so prose that mentions isDm doesn't count. It can be
 * dodged by aliasing (`const x = campaign.isDm` elsewhere) — but the alias
 * line is itself a bare `.isDm` and needs the marker, so the dodge is visible.
 *
 * It does not cover the other half of preview, passing `asPlayer` to
 * reveal-gated reads; see KNOWN_ISSUES.
 */

// Vite reads the files at transform time, so this needs no Node types.
const SOURCES = import.meta.glob<string>(
  ["../pages/**/*.{ts,tsx}", "../components/**/*.{ts,tsx}", "!**/*.test.*"],
  { query: "?raw", import: "default", eager: true },
);
const MARKER = "dm-identity:";

/** Blank out comments, keeping line numbers. Good enough for this codebase. */
function stripComments(text: string): string {
  return text
    .replace(/\/\*[\s\S]*?\*\//g, (block) => block.replace(/[^\n]/g, " "))
    .replace(/(^|[^:])\/\/.*$/gm, "$1");
}

function bareIsDmUses(): string[] {
  const offenders: string[] = [];
  for (const [path, text] of Object.entries(SOURCES)) {
    const original = text.split(/\r?\n/);
    const code = stripComments(original.join("\n")).split("\n");
    code.forEach((line, i) => {
      if (!/\.isDm\b/.test(line)) return;
      const marked =
        original[i].includes(MARKER) || (i > 0 && original[i - 1].includes(MARKER));
      if (!marked) offenders.push(`${path.replace(/^\.\.\//, "src/")}:${i + 1}`);
    });
  }
  return offenders;
}

describe("player preview discipline", () => {
  it("scans the pages and components", () => {
    // Guards against the glob silently matching nothing, which would pass.
    expect(Object.keys(SOURCES).length).toBeGreaterThan(20);
  });

  it("has no unexplained bare campaign.isDm in pages or components", () => {
    // On failure: use `showDmUi` from useDmView for a DM control, or add a
    // `// dm-identity: <why>` comment if the check really is about identity.
    expect(bareIsDmUses()).toEqual([]);
  });
});
