import assert from "node:assert/strict";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the Set It Up launch page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Set It Up \| AI installed and working on your Mac<\/title>/i);
  assert.match(html, /AI on your Mac\. Set up and working\./);
  assert.match(html, /Guided install · \$50 CAD/);
  assert.match(html, /Local AI/);
  assert.match(html, /OpenAI/);
  assert.match(html, /Codex/);
  assert.match(html, /github\.com\/theprincesajjad\/set-it-up-ai/);
  assert.doesNotMatch(html, /codex-preview/);
  assert.doesNotMatch(html, /react-loading-skeleton/);
});

test("includes product-specific social metadata", async () => {
  const response = await render();
  const html = await response.text();

  assert.match(html, /property="og:image"/i);
  assert.match(html, /\/og\.png/);
  assert.match(html, /name="twitter:card" content="summary_large_image"/i);
  assert.match(html, /MIT licensed/);
  assert.match(html, /API usage is billed separately by OpenAI/);
});
