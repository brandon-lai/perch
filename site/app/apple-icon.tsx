import { ImageResponse } from "next/og"
import { IMAGE_TOKENS as palette } from "@/lib/design"
export const size = { width: 180, height: 180 }
export const contentType = "image/png"
export default function Icon() {
  return new ImageResponse(
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        background: palette.paper,
      }}
    >
      <svg
        aria-hidden="true"
        width="130"
        height="130"
        viewBox="0 0 64 64"
        fill={palette.primary}
      >
        <ellipse cx="32" cy="39" rx="15" ry="12" />
        <ellipse cx="16" cy="25" rx="6" ry="8" />
        <ellipse cx="28" cy="18" rx="6" ry="8" />
        <ellipse cx="41" cy="19" rx="6" ry="8" />
        <ellipse cx="51" cy="28" rx="6" ry="8" />
      </svg>
    </div>,
    size
  )
}
