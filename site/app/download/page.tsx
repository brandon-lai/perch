import type { Metadata } from "next"
import Link from "next/link"
import { ArrowDownToLine, ArrowRight, ShieldCheck } from "lucide-react"
import { DownloadDetails } from "@/components/download-details"
import { PixelSprite, pose } from "@/components/pixel-art"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { buttonVariants } from "@/components/ui/button"
import { Kbd, KbdGroup } from "@/components/ui/kbd"

export const metadata: Metadata = { title: "Get the Mac app" }

const RELEASE = "https://github.com/brandon-lai/perch/releases/download/v0.7.0/Perch-0.7.0-universal.zip"

export default function Download() {
  return (
    <main id="main" className="document-page shell">
      <h1>A little red panda, on your actual Mac.</h1>
      <p className="lede">Native Swift, a tree to nap in, and windows to climb. Free while it’s experimental.</p>

      <div className="download-card">
        <div className="sprite-well">
          <PixelSprite grid={pose("sit")} scale={4} label="Maple, the red panda, sitting" />
        </div>
        <div className="download-card-body">
          <Badge variant="tint">Experimental v0.7.0</Badge>
          <h2>Perch for Mac</h2>
          <p className="fine-print">macOS 14 or later · Apple silicon and Intel · 1.4 MB</p>
          <a className={buttonVariants({ size: "lg" })} href={RELEASE}>
            <ArrowDownToLine aria-hidden="true" />
            Download Perch
          </a>
        </div>
      </div>

      <Alert className="notice" role="note">
        <ShieldCheck aria-hidden="true" />
        <AlertTitle>Before you open it</AlertTitle>
        <AlertDescription>
          <p>
            This build isn’t notarized by Apple yet, so macOS may ask you to confirm it the first time. Only install it
            if you’re comfortable trying a source-available prototype.
          </p>
          <DownloadDetails />
        </AlertDescription>
      </Alert>

      <section className="document-section">
        <h2>Ready as it is.</h2>
        <p>Maple is ready to go: one red panda, one look, nothing to set up. Rename it in Settings if you like.</p>
        <ol className="steps">
          <li><span>Click it to pet it. Asleep, it snuggles in; double-click to wake it.</span></li>
          <li><span>Drag it to pick it up, or move a window it’s sitting on and it rides along.</span></li>
          <li><span>Use the paw in your menu bar to take a nap, visit its tree, or play ball.</span></li>
        </ol>
        <div className="keys">
          <KbdGroup>
            <Kbd>⌃</Kbd>
            <Kbd>⌥</Kbd>
            <Kbd>⌘</Kbd>
            <Kbd>B</Kbd>
          </KbdGroup>
          <span>tucks it away. Screen sharing? Tuck it away first.</span>
        </div>
      </section>

      <section className="document-section">
        <h2>A baseline, not a promise.</h2>
        <p>
          The pixel art keeps every pose consistent. Long-term charm, battery use and the performance targets still need
          real-Mac testing. No AI generation or payment is included.
        </p>
        <Link className={buttonVariants({ variant: "link" })} href="/help">
          Read the prototype’s boundaries
          <ArrowRight aria-hidden="true" />
        </Link>
      </section>
    </main>
  )
}
