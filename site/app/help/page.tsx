import type { Metadata } from "next"
import Link from "next/link"
export const metadata: Metadata = { title: "Living with Perch" }
export default function Help() {
  return (
    <main id="main" className="document-page shell">
      <h1>
        A window sill.
        <br />A red panda.
      </h1>
      <p className="lede">
        Perch is a little desktop companion, not an assistant.
      </p>
      <section className="document-section">
        <h2>First few minutes</h2>
        <ol>
          <li>
            <Link href="/download">Download the experimental Mac app</Link> and
            read the installation notes.
          </li>
          <li>
            Open Perch. Maple, a red panda, appears, with a paw in your menu
            bar.
          </li>
          <li>
            Choose Settings to rename it, pick its colors, or import a{" "}
            <Link href="/make">browser-made pack</Link>.
          </li>
          <li>
            Your pointer turns into a stalk of bamboo. Rest it somewhere and
            watch the panda come for it, then shake the pointer to drop it.
            Click to pet it, or drag and let go.
          </li>
        </ol>
      </section>
      <section className="document-section">
        <h2>Keep it out of the way.</h2>
        <p>
          Perch samples the red panda’s visible pixels to switch click handling
          on or off, and clicks pass straight through while it hangs from your
          pointer. This is not a per-pixel macOS input region; brief routing
          delays are possible. Calm mode or quiet hours mean less movement, and
          you can switch off pointer chasing. Bed hides it entirely.
        </p>
        <p>
          Only the arrow becomes bamboo; text cursors and other pointers stay as
          they are. macOS has no public way to do this, so Perch uses the same
          private cursor registry that cursor customizers use. Your own arrow
          comes back when the game pauses, when Perch quits, sleeps or is tucked
          away, and at the next launch if Perch ever crashes. If a future macOS
          blocks it, Perch draws the bamboo beside the arrow instead.
        </p>
        <p>
          The menu bar and <kbd>⌃ ⌥ ⌘ B</kbd> shortcut let you tuck it away.
          Lock notifications pause the app, and a bounds check detects some
          full-screen windows. These paths still need testing across real Spaces
          and displays. Put it to bed before a meeting or screen share.
        </p>
      </section>
      <section className="document-section">
        <h2>Its tree</h2>
        <p>
          A little pixel tree stands at the bottom of your screen. Your red
          panda climbs it to rest, and naps draped over its branch at night or
          when you step away. Drag the tree to move it, or set its place in
          Settings.
        </p>
      </section>
      <section className="document-section">
        <h2>What this build is</h2>
        <p>
          Hand-placed pixel art in three editable colors and three sizes. The
          native app reads real window surfaces. The browser is a preview
          playground, not a desktop overlay.
        </p>
        <p>
          AI generation, hosted gift links, paid plans, optional Accessibility
          observers and keystroke-driven break nudges are not included. No
          retention rates are claimed.
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
