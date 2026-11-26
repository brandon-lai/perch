import type { Metadata } from "next"
import Link from "next/link"
export const metadata: Metadata = { title: "Living with Perch" }
export default function Help() {
  return (
    <main id="main" className="document-page shell">
      <h1>
        A window sill.
        <br />A familiar face.
      </h1>
      <p className="lede">
        Perch is a native desktop companion, not an assistant.
      </p>
      <section className="document-section">
        <h2>First few minutes</h2>
        <ol>
          <li>
            <Link href="/download">Download the experimental Mac app</Link> and
            read the installation notes.
          </li>
          <li>
            Open Perch. A sample pet appears, with a paw in your menu bar.
          </li>
          <li>
            Choose Settings to make a pet from 3 to 10 photos, edit their
            traits, or import a <Link href="/make">browser-made pack</Link>.
          </li>
          <li>
            Slowly move a window beneath your pet. Click to pet them, or drag
            and let go.
          </li>
        </ol>
      </section>
      <section className="document-section">
        <h2>Keep it out of the way.</h2>
        <p>
          Perch samples the pet’s visible pixels to switch click handling on or
          off. This is not a per-pixel macOS input region; brief routing delays
          are possible. Choose a calm rhythm or quiet hours for less movement.
          Bed hides the pet entirely.
        </p>
        <p>
          The menu bar and <kbd>⌃ ⌥ ⌘ B</kbd> shortcut let you tuck them away.
          Lock notifications pause the app, and a bounds check detects some
          full-screen windows. These paths still need testing across real Spaces
          and displays. Put them to bed before a meeting or screen share.
        </p>
      </section>
      <section className="document-section">
        <h2>What this build is</h2>
        <p>
          A shared, flat 2D rig with editable colors, markings and size. The
          native app reads real window surfaces. The browser is a preview
          playground, not a desktop overlay.
        </p>
        <p>
          The photo-to-pet baseline is local and template-based. AI model
          generation, hosted gift links, paid plans, optional Accessibility
          observers and keystroke-driven break nudges are not included. No
          pet-recognition or retention rates are claimed.
        </p>
      </section>
      <section className="document-section">
        <h2>A companion to remember</h2>
        <p>
          If this pet holds a memory, choose the optional remembrance wording.
          Perch does not assume a loss, prompt anniversaries, or turn a memory
          into a separate paid feature.
        </p>
        <a
          className="quiet-link"
          href="https://github.com/brandon-lai/perch/issues"
        >
          Report a prototype issue
        </a>
      </section>
    </main>
  )
}
