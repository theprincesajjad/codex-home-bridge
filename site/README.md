# Codex Home Bridge launch site

The public product page for Codex Home Bridge. It explains the Mac microphone,
Codex CLI, HomePod output, and iPhone presence-gate architecture without
claiming access to a HomePod microphone.

## Local development

Requires Node.js 22.13 or newer.

```bash
npm install
npm run dev
```

## Verification

```bash
npm test
npm audit --omit=dev --audit-level=high
```

The site uses the Sites-compatible vinext build and includes a generated social
preview card plus a screenshot from the tested macOS build.
