import type { Metadata } from "next"
import Link from "next/link"
import { ArrowDownToLine } from "lucide-react"
import { DownloadDetails } from "@/components/download-details"
export const metadata: Metadata = { title: "Get the Mac app" }
export default function Download() {
  return (
    <main id="main" className="document-page shell">
      <h1>
        A little pet.
        <br />
        On your actual Mac.
      </h1>
      <p className="lede">
        Native Swift, a menu bar home, and windows to perch on.
      </p>
      <a
        className="action primary"
        href="https://github.com/brandon-lai/perch/releases/download/v0.1.0/Perch-0.1.0-universal.zip"
      >
        <ArrowDownToLine aria-hidden="true" />
        Download Perch for Mac
      </a>
      <p className="fine-print">
        Experimental v0.1.0. macOS 14 or later. Apple silicon and Intel.
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
        <h2>Bring your pet along.</h2>
        <p>
          Start with the sample pet or choose photos in the Mac app. You can
          also <Link href="/make">make a private template pack here</Link>, then
          import it in Settings.
        </p>
        <p>
          Click to pet, drag to pick up, or move a window underneath. Use the
          menu bar to feed, play, or send your pet to bed.
        </p>
        <p>
          <kbd>⌃ ⌥ ⌘ B</kbd> sends your pet to bed or wakes them. Screen
          sharing? Put them to bed first.
        </p>
      </section>
      <section className="document-section">
        <h2>A baseline, not a promise.</h2>
        <p>
          The template rig keeps markings consistent. Exact photo likeness,
          long-term charm, and the performance targets still need real-pet and
          real-Mac testing. No AI generation or payment is included.
        </p>
        <Link className="quiet-link" href="/help">
          Read the prototype’s boundaries
        </Link>
      </section>
    </main>
  )
}
