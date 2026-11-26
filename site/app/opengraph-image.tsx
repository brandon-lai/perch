import { ImageResponse } from "next/og"
import { readFile } from "node:fs/promises"
import { join } from "node:path"
import { IMAGE_TOKENS as palette } from "@/lib/design"
import { RigDrawing, SOCIAL_RIG_COLORS } from "@/components/pet-rig"
import { SAMPLE_PET } from "@/lib/pack"
export const alt =
  "Perch: a little warm-colored dog resting on a blue window sill."
export const size = { width: 1200, height: 630 }
export const contentType = "image/png"
export default async function OpenGraphImage() {
  const font = await readFile(
    join(process.cwd(), "public/fonts/bricolage-bold.ttf")
  )
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
          Your pet.
        </div>
        <div
          style={{
            fontSize: 88,
            fontWeight: 700,
            lineHeight: 1.04,
            fontFamily: palette.displayFace,
          }}
        >
          A little closer.
        </div>
        <div style={{ fontSize: 25, marginTop: 40 }}>
          Familiar company, on the edge of your windows.
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
        <svg aria-hidden="true" width="330" height="297" viewBox="0 0 160 144">
          {RigDrawing({
            traits: SAMPLE_PET,
            pose: "idle",
            colors: SOCIAL_RIG_COLORS,
          })}
        </svg>
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
