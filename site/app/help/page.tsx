import type { Metadata } from "next"
import Link from "next/link"
import { ArrowRight } from "lucide-react"
import { PixelSprite, pose } from "@/components/pixel-art"
import { buttonVariants } from "@/components/ui/button"
import { Kbd, KbdGroup } from "@/components/ui/kbd"

export const metadata: Metadata = { title: "Living with Perch" }

export default function Help() {
  return (
    <main id="main" className="document-page shell">
      <PixelSprite className="page-sprite" grid={pose("idle")} scale={3} />
      <h1>A window sill. A red panda.</h1>
      <p className="lede">Perch is a little desktop companion, not an assistant. Here’s how it lives.</p>

      <section className="document-section">
        <h2>First few minutes</h2>
        <ol className="steps">
          <li>
            <span>
              <Link href="/download">Download the Mac app</Link> and read the installation notes.
            </span>
          </li>
          <li><span>Open Perch. Maple, a red panda, appears, with a paw in your menu bar.</span></li>
          <li><span>Choose Settings to rename it. There’s nothing else to set up.</span></li>
          <li>
            <span>
              Your pointer turns into a stalk of bamboo. Wake Maple and watch it come for it; shake the pointer to drop
              it. Click to pet it, or drag and let go.
            </span>
          </li>
        </ol>
      </section>

      <section className="document-section">
        <h2>Naps</h2>
        <p>
          Like a real red panda, it rests most of the day: draped over the top edge of a window as if it were a branch,
          between short spells of exploring. Little z’s drift up while it sleeps. Choose Take a nap in the menu to send
          it now; it sleeps until you wake it.
        </p>
        <p>
          While it sleeps, hover to make it peek, click to pet it and it snuggles in, or pick it up and it dozes on in
          your hand; set it down gently and it naps on there. Double-click to wake it, or hold the bamboo by its nose,
          and it stays up a while to play.
        </p>
      </section>

      <section className="document-section">
        <h2>Its tree</h2>
        <p>
          A little pixel tree stands at the bottom of your screen. Your red panda climbs it to rest, and naps draped
          over its branch at night or when you step away. Drag the tree to move it, or set its place in Settings.
        </p>
      </section>

      <section className="document-section">
        <h2>Keep it out of the way</h2>
        <p>
          Perch samples the red panda’s visible pixels to switch click handling on or off, and clicks pass straight
          through while it hangs from your pointer. Brief routing delays are possible. Quiet hours send it to sleep,
          and you can switch off pointer chasing.
        </p>
        <p>
          Only the arrow becomes bamboo; text cursors and other pointers stay as they are. macOS has no public way to
          do this, so Perch uses the same private cursor registry that cursor customizers use. Your own arrow comes
          back when the game pauses, when Perch quits, sleeps or is tucked away, and at the next launch if Perch ever
          crashes. If a future macOS blocks it, Perch draws the bamboo beside the arrow instead.
        </p>
        <div className="keys">
          <KbdGroup>
            <Kbd>⌃</Kbd>
            <Kbd>⌥</Kbd>
            <Kbd>⌘</Kbd>
            <Kbd>B</Kbd>
          </KbdGroup>
          <span>tucks it away, as does the menu bar. Tuck it away before a meeting or screen share.</span>
        </div>
      </section>

      <section className="document-section">
        <h2>What this build is</h2>
        <p>
          Hand-placed pixel art in one look, with nothing to configure. The native app reads real window surfaces; the
          browser is a preview playground, not a desktop overlay. Lock notifications pause the app, and a bounds check
          detects some full-screen windows; these still need testing across real Spaces and displays.
        </p>
        <p>
          AI generation, hosted gift links, paid plans, optional Accessibility observers and keystroke-driven break
          nudges are not included. No retention rates are claimed.
        </p>
        <a className={buttonVariants({ variant: "link" })} href="https://github.com/brandon-lai/perch/issues">
          Report a prototype issue
          <ArrowRight aria-hidden="true" />
        </a>
      </section>
    </main>
  )
}
