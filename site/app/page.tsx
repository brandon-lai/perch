import Link from "next/link"
import { ArrowDownToLine, MousePointer2, Move } from "lucide-react"
import { Playground } from "@/components/playground"

export default function Home() {
  return (
    <main id="main">
      <section className="hero shell">
        <div className="hero-copy">
          <h1>
            Your pet.
            <br />A little closer.
          </h1>
          <p>
            A familiar face on the edge of your windows.
            <br className="desktop-break" /> For the days you spend at your Mac.
          </p>
          <Link className="action primary" href="/download">
            <ArrowDownToLine aria-hidden="true" />
            Get Perch for Mac
          </Link>
          <Link className="quiet-link" href="/make">
            Make a pet from your photos
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
            window sills.
          </h2>
          <p>
            Slow moves, a little ride. Quick moves, a tumble. Your pet finds its
            feet again.
          </p>
          <p className="muted">
            Native Swift. Read-only windows. One shortcut to bed.
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
            Familiar markings.
            <br />
            Private photos.
          </h2>
          <p>
            A shared 2D rig keeps every pose consistent.
            <br />
            Your photos stay on your device.
          </p>
          <Link className="action secondary" href="/make">
            Make your little companion
          </Link>
          <p className="fine-print">
            Experimental template build. Not an AI likeness service.
          </p>
        </div>
      </section>
    </main>
  )
}
