const sourceUrl = "https://github.com/theprincesajjad/set-it-up-ai";

export default function Home() {
  return (
    <main>
      <nav className="nav shell" aria-label="Main navigation">
        <a className="brand" href="#top" aria-label="Set It Up home">
          <span className="brand-mark">S</span>
          <span>SET IT UP</span>
        </a>
        <div className="nav-links">
          <a href="#how">How it works</a>
          <a href="#modes">Three modes</a>
          <a href="#partners">For partners</a>
          <a href={sourceUrl} target="_blank" rel="noreferrer">
            Source
          </a>
        </div>
        <a className="nav-cta" href="#install">
          Book an install
        </a>
      </nav>

      <section className="hero shell" id="top">
        <div className="hero-copy">
          <p className="eyebrow">OPEN SOURCE SOFTWARE · GUIDED MAC INSTALL</p>
          <h1>AI on your Mac. Set up and working.</h1>
          <p className="hero-lede">
            Choose private local AI, your own OpenAI API access, or Codex for
            bigger computer tasks. We install one path, secure it, and prove it
            with a live request.
          </p>
          <div className="hero-actions">
            <a className="button button-primary" href="#install">
              Guided install · $50 CAD
            </a>
            <a
              className="button button-secondary"
              href={sourceUrl}
              target="_blank"
              rel="noreferrer"
            >
              View the source
              <span aria-hidden="true">↗</span>
            </a>
          </div>
          <ul className="signal-list" aria-label="Product facts">
            <li>MIT licensed</li>
            <li>macOS 14+</li>
            <li>Customer-owned AI access</li>
          </ul>
        </div>

        <div className="product-frame" aria-label="Set It Up app preview">
          <div className="frame-head">
            <div>
              <p>WORKING BUILD · 0.4</p>
              <strong>LOCAL AI · OPENAI · CODEX</strong>
            </div>
            <span className="live-dot" aria-hidden="true" />
          </div>
          <img
            src="/set-it-up-app.jpg"
            alt="Set It Up macOS app showing the local AI, OpenAI, and Codex modes"
          />
          <p className="frame-note">
            Real macOS build. Mac owner verified. Local AI shown without a
            cloud account.
          </p>
        </div>
      </section>

      <section className="trust-strip" aria-label="Product principles">
        <div className="shell trust-grid">
          <p>Local AI stays on the Mac when Ollama does</p>
          <p>OpenAI keys live in macOS Keychain</p>
          <p>Codex actions begin read-only</p>
        </div>
      </section>

      <section className="section shell" id="how">
        <div className="section-heading">
          <p className="eyebrow">ONE PRACTICAL SESSION</p>
          <h2>We make the first useful request work.</h2>
          <p>
            No mystery bundle and no fake universal assistant. We choose the
            right mode for the customer’s Mac, finish the setup, and explain
            exactly what it can and cannot do.
          </p>
        </div>
        <ol className="steps">
          <li>
            <span>01</span>
            <h3>Choose a mode</h3>
            <p>Private local chat, customer-owned OpenAI API, or Codex tasks.</p>
          </li>
          <li>
            <span>02</span>
            <h3>Install the app</h3>
            <p>Build, permissions, microphone, model or account, and launch.</p>
          </li>
          <li>
            <span>03</span>
            <h3>Secure the Mac</h3>
            <p>Owner authentication, Keychain storage, and safe defaults.</p>
          </li>
          <li>
            <span>04</span>
            <h3>Prove it live</h3>
            <p>A typed request and “Set It Up” voice request before handoff.</p>
          </li>
        </ol>
      </section>

      <section className="section shell" id="modes">
        <div className="section-heading compact">
          <p className="eyebrow">THREE HONEST MODES</p>
          <h2>Start private. Connect more power when it earns its place.</h2>
        </div>
        <div className="comparison-grid mode-grid">
          <article>
            <span className="article-index">LOCAL</span>
            <h3>Private AI on the Mac</h3>
            <p>
              Ollama runs the model locally. Best for chat, drafting, and
              private everyday questions. Model download and performance
              depend on the customer’s Mac.
            </p>
          </article>
          <article>
            <span className="article-index">OPENAI</span>
            <h3>Cloud AI with your key</h3>
            <p>
              The customer supplies an OpenAI API key and model. The key is
              saved in Keychain. API usage is billed separately by OpenAI.
            </p>
          </article>
          <article>
            <span className="article-index">CODEX</span>
            <h3>Bigger computer tasks</h3>
            <p>
              A signed-in Codex installation can inspect or edit a selected
              workspace. Read-only is the default; workspace write is explicit.
            </p>
          </article>
        </div>
      </section>

      <section className="security-section" id="security">
        <div className="shell security-grid">
          <div className="security-copy">
            <p className="eyebrow">SECURITY THAT MATCHES THE CLAIM</p>
            <h2>The owner unlocks it. The selected mode sets the boundary.</h2>
            <p>
              The app locks when the Mac session becomes inactive. It receives
              no fingerprint data, stores no audio recordings, and does not
              expose unrestricted system access.
            </p>
          </div>
          <div className="security-specs">
            <div>
              <span>LOCAL</span>
              <p>Loopback-only endpoint for local AI mode</p>
            </div>
            <div>
              <span>KEYCHAIN</span>
              <p>Device-only storage for the OpenAI API key</p>
            </div>
            <div>
              <span>READ</span>
              <p>Default Codex permission for workspace inspection</p>
            </div>
            <div>
              <span>LOCK</span>
              <p>Fresh Mac owner check after session unlock</p>
            </div>
          </div>
        </div>
      </section>

      <section className="section shell partner-section" id="partners">
        <div className="section-heading">
          <p className="eyebrow">INSTALL PARTNERS</p>
          <h2>A simple $50 add-on for gadget and computer shops.</h2>
          <p>
            Partners can offer a finished AI setup when a customer buys,
            repairs, or upgrades a Mac. The software stays free; the charge is
            for the guided installation and working handoff.
          </p>
        </div>
        <div className="partner-grid">
          <div>
            <strong>$50 CAD</strong>
            <span>one-time customer install</span>
          </div>
          <div>
            <strong>1 path</strong>
            <span>local AI, OpenAI API, or Codex</span>
          </div>
          <div>
            <strong>Live proof</strong>
            <span>first working voice and typed request</span>
          </div>
          <div>
            <strong>Open source</strong>
            <span>customer keeps the app and source</span>
          </div>
        </div>
        <p className="partner-note">
          Retail partner terms and any revenue share are agreed before the
          offer is listed. The $50 fee does not include model downloads,
          third-party subscriptions, API usage, or hardware.
        </p>
      </section>

      <section className="setup-section" id="install">
        <div className="shell setup-grid">
          <div>
            <p className="eyebrow">GUIDED INSTALL</p>
            <h2>Free software. $50 to set it up properly.</h2>
            <p className="setup-lede">
              One Mac, one assistant path, owner authentication, audio setup,
              and one proven request. If the chosen service needs an account or
              paid usage, the customer owns and pays for it directly.
            </p>
          </div>
          <div className="offer">
            <p className="offer-label">ONE-TIME MAC INSTALL</p>
            <div className="price">
              <span>$50</span>
              <small>CAD</small>
            </div>
            <ul>
              <li>Set It Up installation</li>
              <li>One AI mode configured</li>
              <li>Mac owner authentication</li>
              <li>Voice, typed request, and audio check</li>
              <li>Removal and switching handoff</li>
            </ul>
            <button className="button button-primary checkout-pending" disabled>
              Checkout link is being connected
            </button>
            <p className="offer-note">
              We are at the Stripe setup step. No payment link is public yet.
            </p>
          </div>
        </div>
      </section>

      <footer className="footer shell">
        <div className="brand">
          <span className="brand-mark">S</span>
          <span>SET IT UP</span>
        </div>
        <p>
          Unofficial software. Not affiliated with or endorsed by OpenAI,
          Apple, or Ollama. Product names belong to their respective owners.
        </p>
        <a href={sourceUrl} target="_blank" rel="noreferrer">
          GitHub ↗
        </a>
      </footer>
    </main>
  );
}
