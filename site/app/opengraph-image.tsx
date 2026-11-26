import { ImageResponse } from "next/og"
import { readFile } from "node:fs/promises"
import { join } from "node:path"
import { IMAGE_TOKENS as palette } from "@/lib/design"
export const alt =
  "Perch: a little pixel red panda sitting on a blue window sill."
export const size = { width: 1200, height: 630 }
export const contentType = "image/png"
export default async function OpenGraphImage() {
  const font = await readFile(
    join(process.cwd(), "public/fonts/bricolage-bold.ttf")
  )
  // Drawn by the Mac app's own renderer (`--export-site-art`), already at 8× so nothing is smoothed.
  const panda = await readFile(join(process.cwd(), "public/panda/panda-sit.png"))
  return new ImageResponse(
    <div
      style={{
        display: "flex",
        width: "100%",
        height: "100%",
        background: palette.paper,
        color: palette.ink,
        padding: "70px",
        justifyContent: "space-between",
        alignItems: "center",
      }}
    >
      <div style={{ display: "flex", flexDirection: "column", width: 660 }}>
        <div
          style={{
            fontSize: 28,
            marginBottom: 48,
            fontFamily: palette.displayFace,
            fontWeight: 700,
          }}
        >
          perch
        </div>
        <div
          style={{
            fontSize: 88,
            fontWeight: 700,
            lineHeight: 1.04,
            fontFamily: palette.displayFace,
          }}
        >
          A red panda
        </div>
        <div
          style={{
            fontSize: 88,
            fontWeight: 700,
            lineHeight: 1.04,
            fontFamily: palette.displayFace,
          }}
        >
          for your desktop.
        </div>
        <div style={{ fontSize: 25, marginTop: 40 }}>
          It climbs your windows, chases your pointer and naps in its tree.
        </div>
      </div>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          width: 340,
          marginTop: 100,
        }}
      >
        <img
          alt=""
          width={256}
          height={256}
          src={`data:image/png;base64,${panda.toString("base64")}`}
        />
        <div
          style={{
            width: 340,
            height: 22,
            borderRadius: 10,
            background: palette.ledge,
          }}
        />
      </div>
    </div>,
    {
      ...size,
      fonts: [
        { name: palette.displayFace, data: font, weight: 700, style: "normal" },
      ],
    }
  )
}
