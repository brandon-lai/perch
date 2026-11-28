import { ImageResponse } from "next/og"
import { readFile } from "node:fs/promises"
import { join } from "node:path"
import { IMAGE_TOKENS as palette, PAW_RUNS } from "@/lib/design"
export const alt = "Perch: a little pixel red panda sitting on top of a window."
export const size = { width: 1200, height: 630 }
export const contentType = "image/png"
export default async function OpenGraphImage() {
  const font = await readFile(join(process.cwd(), "public/fonts/bricolage-bold.ttf"))
  // Drawn by the Mac app's own renderer (`--export-site-art`), already at 8× so nothing is smoothed.
  const panda = await readFile(join(process.cwd(), "public/panda/panda-sit.png"))
  const dot = (color: string) => <div style={{ width: 14, height: 14, borderRadius: 7, background: color }} />
  return new ImageResponse(
    <div style={{ display: "flex", width: "100%", height: "100%", background: palette.paper, color: palette.ink, padding: 64, gap: 56, alignItems: "center" }}>
      <div style={{ display: "flex", flexDirection: "column", width: 600 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 14, fontSize: 34, marginBottom: 44, fontFamily: palette.displayFace, fontWeight: 700 }}>
          <svg width={44} height={36} viewBox="0 0 11 9" shapeRendering="crispEdges">
            {PAW_RUNS.map(([x, y, n]) => (
              <rect key={`${x}-${y}`} x={x} y={y} width={n} height={1} fill={palette.primary} />
            ))}
          </svg>
          perch
        </div>
        <div style={{ fontSize: 84, fontWeight: 700, lineHeight: 1.02, letterSpacing: -3, fontFamily: palette.displayFace }}>A red panda</div>
        <div style={{ fontSize: 84, fontWeight: 700, lineHeight: 1.02, letterSpacing: -3, fontFamily: palette.displayFace }}>for your desktop.</div>
        <div style={{ fontSize: 27, marginTop: 36, color: palette.muted, lineHeight: 1.4 }}>
          It naps on your windows like they’re branches, and plays when you wake it.
        </div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", justifyContent: "flex-end", alignItems: "center", width: 416, height: 470, background: palette.sky, borderRadius: 40, paddingTop: 40, overflow: "hidden" }}>
        <img alt="" width={256} height={256} src={`data:image/png;base64,${panda.toString("base64")}`} />
        <div style={{ display: "flex", flexDirection: "column", width: 330, height: 150, background: palette.card, borderRadius: "22px 22px 0 0", boxShadow: "0 0 0 2px rgba(31,25,20,0.06)" }}>
          <div style={{ display: "flex", gap: 9, padding: "11px 16px", borderBottom: `2px solid ${palette.rule}` }}>
            {dot(palette.dotClose)}
            {dot(palette.dotMin)}
            {dot(palette.dotZoom)}
          </div>
        </div>
      </div>
    </div>,
    { ...size, fonts: [{ name: palette.displayFace, data: font, weight: 700, style: "normal" }] }
  )
}
