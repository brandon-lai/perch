import Link from "next/link"
import { ArrowDownToLine, MousePointer2, Move } from "lucide-react"
import { Playground } from "@/components/playground"

export default function Home() {
  return (
    <main id="main">
      <section className="hero shell">
        <div className="hero-copy">
          <h1>
            A red panda
            <br />
            for your desktop.
          </h1>
          <p>
            It climbs your windows and chases your pointer.
            <br className="desktop-break" /> Then it naps in its little tree.
          </p>
          <Link className="action primary" href="/download">
            <ArrowDownToLine aria-hidden="true" />
            Get Perch for Mac
          </Link>
          <Link className="quiet-link" href="/make">
            Make your red panda
          </Link>
        </div>
        <div className="hero-pet">
          <Playground />
          <div className="play-hint">
            <Move aria-hidden="true" />
            <p>Move the perch. See who comes along.</p>
          </div>
        </div>
      </section>
      <section className="native-section shell">
        <div>
          <h2>
            Windows become
            <br />
            branches.
          </h2>
          <p>
            It crawls up window faces, gallops along the Dock and leaps for the
            bamboo on your pointer. Shake it off and it comes right back.
          </p>
          <p className="muted">
            Native Swift. Reads window positions only. One shortcut to bed.
          </p>
          <Link className="quiet-link" href="/help">
            How the desktop companion works
          </Link>
        </div>
        <div className="small-scene">
          <Playground compact />
          <p className="scene-caption">
            <MousePointer2 aria-hidden="true" />
            Try a pet, a snack, or a little nap.
          </p>
        </div>
      </section>
      <section className="privacy-band">
        <div className="shell">
          <h2>
            One red panda.
            <br />
            Your colors.
          </h2>
          <p>
            Hand-placed pixel art, the same little face in every pose.
            <br />
            Nothing leaves your Mac.
          </p>
          <Link className="action secondary" href="/make">
            Make your red panda
          </Link>
          <p className="fine-print">
            Experimental build. Not notarized by Apple.
          </p>
        </div>
      </section>
    </main>
  )
}
