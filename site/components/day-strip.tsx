import { bamboo, PixelSprite, pose, tree, zs } from "@/components/pixel-art"

/** Art pixels per CSS pixel in the strip: the same grid in every moment. */
const S = 3
/** In the drape pose, the outline row under its belly sits on the edge (as in the Mac app). */
const DRAPE_EDGE = 19

/**
 * A day in its life, drawn from the Mac app's own poses and placed the way the app places them: belly on a window's
 * top edge, paws on a window's side, teeth on the bamboo's end, asleep on its tree's branch.
 */
export function DayStrip() {
  return (
    <ol className="day-strip">
      <li className="moment">
        <div className="moment-art" aria-hidden="true">
          <div className="art-window" style={{ left: 18, right: 18, top: 132, bottom: -24, borderRadius: "14px 14px 0 0" }} />
          <PixelSprite className="art" grid={pose("drape")} scale={S} style={{ top: 132 - DRAPE_EDGE * S, left: "calc(50% - 48px)" }} />
          <PixelSprite className="art" grid={zs.grid} palette={zs.palette} scale={2} style={{ top: 49, left: "calc(50% + 30px)" }} />
        </div>
        <h3>Naps on your windows</h3>
        <p>Most of the day it’s asleep on a window’s top edge, as if it were a branch.</p>
      </li>
      <li className="moment">
        <div className="moment-art" aria-hidden="true">
          <div className="art-window" style={{ left: "calc(50% + 16px)", right: -30, top: 28, bottom: -24, borderRadius: "14px 0 0 0" }} />
          <PixelSprite className="art" grid={pose("scale")} scale={S} style={{ top: 40, left: "calc(50% + 16px - 72px)" }} />
        </div>
        <h3>Climbs the edges</h3>
        <p>Up a window’s side, hand over hand underneath, and over the top, always side on.</p>
      </li>
      <li className="moment">
        <div className="moment-art" aria-hidden="true">
          {/* The stalk is held up in front of its face, its bottom end at the panda's teeth. */}
          <PixelSprite className="art" grid={pose("hang")} scale={S} style={{ top: 77, left: "calc(50% - 48px)" }} />
          <PixelSprite className="art" grid={bamboo.grid} palette={bamboo.palette} scale={S} style={{ top: 50, left: "calc(50% - 30px)" }} />
        </div>
        <h3>Wakes up for bamboo</h3>
        <p>Your pointer is a stalk of bamboo. Wake it up and it comes to eat it.</p>
      </li>
      <li className="moment">
        <div className="moment-art dusk" aria-hidden="true">
          <div className="art-floor" />
          <PixelSprite className="art" grid={tree.grid} palette={tree.palette} scale={S} style={{ top: 8, left: "calc(50% - 84px)" }} />
          <PixelSprite className="art" grid={pose("drape")} scale={S} style={{ top: 8 + (41 - DRAPE_EDGE) * S, left: "calc(50% - 84px + 60px)" }} />
          <PixelSprite className="art" grid={zs.grid} palette={zs.palette} scale={2} style={{ top: 48, left: "calc(50% + 54px)" }} />
        </div>
        <h3>Has a little tree</h3>
        <p>Its own spot at the bottom of your screen, for the night or when you step away.</p>
      </li>
    </ol>
  )
}
