import type { CSSProperties } from "react"
import Link from "next/link"
import { ArrowDownToLine, ArrowRight, Check, Cpu, Laptop, MousePointer2, Move } from "lucide-react"
import { DayStrip } from "@/components/day-strip"
import { PixelHeart, PixelSprite, pose, tree, zs } from "@/components/pixel-art"
import { Playground } from "@/components/playground"
import { Badge } from "@/components/ui/badge"
import { buttonVariants } from "@/components/ui/button"

const step = (i: number) => ({ "--i": i }) as CSSProperties

export default function Home() {
  return (
    <main id="main">
      <section className="hero shell">
        <div className="hero-copy">
          <Badge variant="tint" className="pill-badge rise" style={step(0)}>
            <PixelHeart />
            New in 0.7: it naps on your windows
          </Badge>
          <h1 className="rise" style={step(1)}>A red panda for your desktop.</h1>
          <p className="hero-lede rise" style={step(2)}>
            A tiny pixel companion that naps on your windows like they’re branches, climbs their edges, and wakes up to
            chase your pointer.
          </p>
          <div className="hero-actions rise" style={step(3)}>
            <Link className={buttonVariants({ size: "lg" })} href="/download">
              <ArrowDownToLine aria-hidden="true" />
              Download for Mac
            </Link>
            <Link className={buttonVariants({ variant: "ghost", size: "lg" })} href="/help">
              How it works
              <ArrowRight aria-hidden="true" />
            </Link>
          </div>
          <p className="hero-meta rise" style={step(3)}>
            <span>
              <Laptop aria-hidden="true" />
              macOS 14 or later
            </span>
            <span>
              <Cpu aria-hidden="true" />
              Apple silicon and Intel
            </span>
          </p>
        </div>
        <div className="scene rise" style={step(4)}>
          <Playground />
          <p className="scene-footer">
            <Move aria-hidden="true" />
            Drag the little window. See who comes along.
          </p>
        </div>
      </section>

      <section className="section shell" aria-labelledby="day-title">
        <div className="section-head">
          <p className="eyebrow">A day in its life</p>
          <h2 id="day-title">Mostly naps. Then a little mischief.</h2>
          <p>Like a real red panda, it rests most of the day and wakes up curious. Every pose is hand-placed pixel art.</p>
        </div>
        <DayStrip />
      </section>

      <section className="section shell try">
        <div className="try-copy">
          <p className="eyebrow">Try it here</p>
          <h2>Windows become branches.</h2>
          <p>
            On your Mac it climbs around your real windows’ edges and rides along when you move them. Here, give it a
            pet, an apple, or a little nap.
          </p>
          <Link className={buttonVariants({ variant: "link" })} href="/help">
            How the desktop companion works
            <ArrowRight aria-hidden="true" />
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

      <section className="section shell">
        <div className="closing">
          <div className="closing-copy">
            <h2>One red panda. Its own life.</h2>
            <p>Nothing to set up and nothing to look after. It keeps you company and stays out of the way.</p>
            <ul className="check-list">
              {[
                "Nothing leaves your Mac: no account, no uploads, no tracking",
                "Reads only where windows are, never what’s in them",
                "One shortcut tucks it away before a screen share",
              ].map((item) => (
                <li key={item}>
                  <span className="tick">
                    <Check aria-hidden="true" />
                  </span>
                  {item}
                </li>
              ))}
            </ul>
            <Link className={buttonVariants({ size: "lg" })} href="/download">
              <ArrowDownToLine aria-hidden="true" />
              Download for Mac
            </Link>
            <p className="fine-print">Free and experimental. Not yet notarized by Apple.</p>
          </div>
          <div className="closing-art" aria-hidden="true">
            <PixelSprite className="art" grid={tree.grid} palette={tree.palette} scale={4} style={{ left: 0, bottom: 0 }} />
            <PixelSprite className="art" grid={pose("drape")} scale={4} style={{ left: 80, top: (41 - 19) * 4 }} />
            <PixelSprite className="art" grid={zs.grid} palette={zs.palette} scale={2} style={{ left: 184, top: 66 }} />
          </div>
        </div>
      </section>
    </main>
  )
}
