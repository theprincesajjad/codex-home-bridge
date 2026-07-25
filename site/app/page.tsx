export default function Home() {
  return (
    <main>
      <nav className="nav shell" aria-label="Main navigation">
        <a className="brand" href="#top" aria-label="Codex Home Bridge home">
          <span className="brand-mark">C</span>
          <span>CODEX HOME BRIDGE</span>
        </a>
        <div className="nav-links">
          <a href="#how">How it works</a>
          <a href="#security">Phone gate</a>
          <a
            href="https://github.com/theprincesajjad/codex-home-bridge"
            target="_blank"
            rel="noreferrer"
          >
            Source
          </a>
        </div>
        <a className="nav-cta" href="#setup">
          Get set up
        </a>
      </nav>

      <section className="hero shell" id="top">
        <div className="hero-copy">
          <p className="eyebrow">UNOFFICIAL · OPEN SOURCE · LOCAL-FIRST</p>
          <h1>Tell your Mac. Codex gets it done.</h1>
          <p className="hero-lede">
            A practical voice bridge for Codex on macOS. Say “Hey Codex,” let
            your Mac handle the request, and hear the answer on your HomePod.
            Your enrolled iPhone keeps the listener locked when you are away.
          </p>
          <div className="hero-actions">
            <a
              className="button button-primary"
              href="https://github.com/theprincesajjad/codex-home-bridge"
              target="_blank"
              rel="noreferrer"
            >
              View the source
              <span aria-hidden="true">↗</span>
            </a>
            <a className="button button-secondary" href="#setup">
              Founding setup · $99
            </a>
          </div>
          <ul className="signal-list" aria-label="Product facts">
            <li>MIT licensed</li>
            <li>macOS 14+</li>
            <li>No API key stored</li>
          </ul>
        </div>

        <div className="product-frame" aria-label="Codex Home Bridge app preview">
          <div className="frame-head">
            <div>
              <p>LIVE BUILD · 0.2</p>
              <strong>PHONE GATE ACTIVE</strong>
            </div>
            <span className="live-dot" aria-hidden="true" />
          </div>
          <img
            src="/bridge-app.png"
            alt="Codex Home Bridge macOS app showing an enrolled phone present on the local network"
          />
          <p className="frame-note">
            Real build. Real phone heartbeat. Test pairing code already rotated.
          </p>
        </div>
      </section>

      <section className="trust-strip" aria-label="Product principles">
        <div className="shell trust-grid">
          <p>Runs through your existing Codex sign-in</p>
          <p>Apple Speech, with on-device recognition when available</p>
          <p>HomePod audio through macOS AirPlay output</p>
        </div>
      </section>

      <section className="section shell" id="how">
        <div className="section-heading">
          <p className="eyebrow">THE HONEST ARCHITECTURE</p>
          <h2>A useful bridge, built around what Apple actually exposes.</h2>
          <p>
            HomePod microphones are not available to ordinary Mac apps. The
            bridge uses the Mac microphone for input and your selected HomePod
            for spoken output.
          </p>
        </div>

        <ol className="steps">
          <li>
            <span>01</span>
            <h3>Say it</h3>
            <p>“Hey Codex” wakes the listener and captures your request.</p>
          </li>
          <li>
            <span>02</span>
            <h3>Mac hears</h3>
            <p>Apple Speech transcribes locally when the system supports it.</p>
          </li>
          <li>
            <span>03</span>
            <h3>Codex acts</h3>
            <p>Your signed-in Codex CLI works inside the permission you choose.</p>
          </li>
          <li>
            <span>04</span>
            <h3>HomePod answers</h3>
            <p>macOS speaks the concise response through your current output.</p>
          </li>
        </ol>
      </section>

      <section className="security-section" id="security">
        <div className="shell security-grid">
          <div className="security-copy">
            <p className="eyebrow">PRESENCE, NOT GUESSWORK</p>
            <h2>Your iPhone is the key.</h2>
            <p>
              The Mac hosts a tiny local pairing page. Your iPhone enters a
              rotating six-digit code and sends a heartbeat while both devices
              are on the same network.
            </p>
          </div>

          <div className="security-specs">
            <div>
              <span>18 sec</span>
              <p>Listener lockout after the heartbeat disappears</p>
            </div>
            <div>
              <span>7 / 30 days</span>
              <p>User-selectable pairing credential rotation</p>
            </div>
            <div>
              <span>5 tries</span>
              <p>Rate limit before a one-minute pairing cooldown</p>
            </div>
            <div>
              <span>0 scans</span>
              <p>No blind sweep that guesses which Wi-Fi device is yours</p>
            </div>
          </div>
        </div>
      </section>

      <section className="section shell comparison">
        <div className="section-heading compact">
          <p className="eyebrow">BUILT FOR CONTROL</p>
          <h2>Open source by default. Permissioned by design.</h2>
        </div>
        <div className="comparison-grid">
          <article>
            <span className="article-index">A</span>
            <h3>Read only starts safe</h3>
            <p>
              Ask questions and inspect a workspace without giving Codex write
              access. Switch to workspace write only when the task needs it.
            </p>
          </article>
          <article>
            <span className="article-index">B</span>
            <h3>No dangerous mode exposed</h3>
            <p>
              The bridge intentionally does not offer unrestricted system
              access. Important changes still deserve review.
            </p>
          </article>
          <article>
            <span className="article-index">C</span>
            <h3>Inspect every line</h3>
            <p>
              The macOS app, pairing server, wake-phrase parser, tests, and
              launch site are available under the MIT license.
            </p>
          </article>
        </div>
      </section>

      <section className="setup-section" id="setup">
        <div className="shell setup-grid">
          <div>
            <p className="eyebrow">FOUNDING SETUP</p>
            <h2>Software free. Guided install $99.</h2>
            <p className="setup-lede">
              For the first 50 Mac users who want the bridge configured,
              secured, and working with their own HomePod.
            </p>
          </div>
          <div className="offer">
            <p className="offer-label">ONE-TIME REMOTE SETUP</p>
            <div className="price">
              <span>$99</span>
              <small>CAD</small>
            </div>
            <ul>
              <li>Build and local installation</li>
              <li>iPhone presence gate pairing</li>
              <li>HomePod output setup</li>
              <li>First live “Hey Codex” task</li>
            </ul>
            <button className="button button-primary checkout-pending" disabled>
              Checkout link is being connected
            </button>
            <p className="offer-note">
              You keep the source and can remove the app at any time.
            </p>
          </div>
        </div>
      </section>

      <footer className="footer shell">
        <div className="brand">
          <span className="brand-mark">C</span>
          <span>CODEX HOME BRIDGE</span>
        </div>
        <p>
          Unofficial software. Not affiliated with or endorsed by OpenAI or
          Apple. Codex, HomePod, macOS, and iPhone are trademarks of their
          respective owners.
        </p>
        <a
          href="https://github.com/theprincesajjad/codex-home-bridge"
          target="_blank"
          rel="noreferrer"
        >
          GitHub ↗
        </a>
      </footer>
    </main>
  );
}
