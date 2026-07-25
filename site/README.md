# Set It Up launch site

The public product page for Set It Up. It explains the local AI, OpenAI API, and
Codex modes; the $50 guided Mac installation; and the install-partner offer.

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
