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

test("server-renders the Codex Home Bridge launch page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Codex Home Bridge \| Your iPhone is the key<\/title>/i);
  assert.match(html, /Tell your Mac\. Codex gets it done\./);
  assert.match(html, /Your iPhone is the key\./);
  assert.match(html, /Founding setup · \$99/);
  assert.match(html, /github\.com\/theprincesajjad\/codex-home-bridge/);
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
});
