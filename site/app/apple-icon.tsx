import { ImageResponse } from "next/og"
import { IMAGE_TOKENS as palette, PAW_RUNS } from "@/lib/design"
export const size = { width: 180, height: 180 }
export const contentType = "image/png"
export default function Icon() {
  const unit = 12
  return new ImageResponse(
    <div style={{ width: "100%", height: "100%", display: "flex", justifyContent: "center", alignItems: "center", background: palette.paper }}>
      <svg aria-hidden="true" width={11 * unit} height={9 * unit} viewBox="0 0 11 9" shapeRendering="crispEdges">
        {PAW_RUNS.map(([x, y, n]) => (
          <rect key={`${x}-${y}`} x={x} y={y} width={n} height={1} fill={palette.primary} />
        ))}
      </svg>
    </div>,
    size
  )
}
