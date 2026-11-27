import type { Metadata } from "next"
import Link from "next/link"
import { ArrowDownToLine } from "lucide-react"
import { DownloadDetails } from "@/components/download-details"
export const metadata: Metadata = { title: "Get the Mac app" }
export default function Download() {
  return (
    <main id="main" className="document-page shell">
      <h1>
        A little red panda.
        <br />
        On your actual Mac.
      </h1>
      <p className="lede">
        Native Swift, a tree to nap in, and windows to climb.
      </p>
      <a
        className="action primary"
        href="https://github.com/brandon-lai/perch/releases/download/v0.7.0/Perch-0.7.0-universal.zip"
      >
        <ArrowDownToLine aria-hidden="true" />
        Download Perch for Mac
      </a>
      <p className="fine-print">
        Experimental v0.7.0. macOS 14 or later. Apple silicon and Intel.
      </p>
      <div className="download-warning">
        <h2>Before you open it</h2>
        <p>
          This experimental build is ad-hoc signed, not Apple-notarized. macOS
          may refuse to open it. Only install it if you are comfortable
          evaluating a source-available prototype.
        </p>
        <DownloadDetails />
      </div>
      <section className="document-section">
        <h2>Ready as it is.</h2>
        <p>
          Maple is ready to go: one red panda, one look, nothing to set up.
          Rename it in Settings if you like.
        </p>
        <p>
          Click to pet, drag to pick up, or move a window underneath. Use the
          menu bar to send it to its tree, play ball, or take a nap. Asleep,
          a click makes it snuggle in and a double-click wakes it.
        </p>
        <p>
          <kbd>⌃ ⌥ ⌘ B</kbd> tucks it away. Screen sharing? Tuck it away
          first.
        </p>
      </section>
      <section className="document-section">
        <h2>A baseline, not a promise.</h2>
        <p>
          The pixel art keeps every pose consistent. Long-term charm, battery
          use and the performance targets still need real-Mac testing. No AI
          generation or payment is included.
        </p>
        <Link className="quiet-link" href="/help">
          Read the prototype’s boundaries
        </Link>
      </section>
    </main>
  )
}
