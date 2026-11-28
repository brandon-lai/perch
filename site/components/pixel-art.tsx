import type { CSSProperties } from "react"
import { cn } from "cn"
import art from "@/lib/panda-art.json"
import { RED_PANDA_COLORS } from "@/lib/pack"
import { fixedPalette, hex, pandaPalette, rgba, type Palette } from "@/lib/pixel"

type Grid = readonly string[]
type Poses = Record<string, { frames: string[][] }>

const panda = pandaPalette(RED_PANDA_COLORS.coat, RED_PANDA_COLORS.earColor, RED_PANDA_COLORS.markingColor)
export const tree = { grid: art.tree.grid, palette: fixedPalette(art.tree.colors, art.tree.outline) }
export const bamboo = { grid: art.bamboo.grid, palette: fixedPalette(art.bamboo.colors, art.bamboo.outline) }

/** One frame of one of the Mac app's red panda poses. */
export function pose(name: string, frame = 0): Grid {
  const poses = art.poses as unknown as Poses
  return (poses[name] ?? poses.idle).frames[frame] ?? poses.idle.frames[0]
}

/** The z's that rise over a sleeping panda, as in the Mac app: cream with a plum shadow, never outlined. */
export const zs: { grid: Grid; palette: Palette } = (() => {
  const width = 18, height = 19
  const g = Array.from({ length: height }, () => Array<string>(width).fill("."))
  const z = (n: number, x: number, y: number) => {
    for (let i = 0; i < n; i++) { g[y][x + i] = "Y"; g[y + n - 1][x + i] = "Y" }
    for (let i = 1; i < n - 1; i++) g[y + i][x + n - 1 - i] = "Y"
  }
  z(4, 0, 14); z(5, 5, 7); z(6, 11, 0)
  for (let y = height - 2; y >= 0; y--) for (let x = 0; x < width - 1; x++) if (g[y][x] === "Y" && g[y + 1][x + 1] === ".") g[y + 1][x + 1] = "y"
  return {
    grid: g.map((row) => row.join("")),
    palette: { colors: { Y: hex("#FBF1DF"), y: hex("#5A3340") }, outline: hex("#5A3340"), softOutline: hex("#5A3340"), softChars: new Set(), post: new Set(["Y", "y"]) },
  }
})()

/** Merges each row's runs of one colour into a single path per colour. */
function paths(grid: Grid, palette: Palette) {
  const data = rgba(grid, palette), height = grid.length, width = grid[0]?.length ?? 0
  const byColor = new Map<string, string>()
  for (let y = 0; y < height; y++) {
    let x = 0
    while (x < width) {
      const i = (y * width + x) * 4
      if (data[i + 3] === 0) { x++; continue }
      let n = 1
      while (x + n < width) {
        const j = (y * width + x + n) * 4
        if (data[j + 3] === 0 || data[j] !== data[i] || data[j + 1] !== data[i + 1] || data[j + 2] !== data[i + 2]) break
        n++
      }
      const fill = `rgb(${data[i]} ${data[i + 1]} ${data[i + 2]})`
      byColor.set(fill, (byColor.get(fill) ?? "") + `M${x} ${y}h${n}v1h-${n}z`)
      x += n
    }
  }
  return [...byColor].map(([fill, d]) => ({ fill, d }))
}

/**
 * Pixel art from the Mac app's own sprite grids, as crisp SVG (art-pixel units, scaled up). Decorative unless it's
 * given a label.
 */
export function PixelSprite({
  grid,
  palette = panda,
  scale = 3,
  flip = false,
  label,
  className,
  style,
}: {
  grid: Grid
  palette?: Palette
  scale?: number
  flip?: boolean
  label?: string
  className?: string
  style?: CSSProperties
}) {
  const height = grid.length, width = grid[0]?.length ?? 0
  return (
    <svg
      className={cn("pixel", className)}
      width={width * scale}
      height={height * scale}
      viewBox={`0 0 ${width} ${height}`}
      shapeRendering="crispEdges"
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      focusable="false"
      style={{ ...(flip ? { transform: "scaleX(-1)" } : null), ...style }}
    >
      {paths(grid, palette).map((p) => (
        <path key={p.fill} d={p.d} fill={p.fill} />
      ))}
    </svg>
  )
}

/** Perch's mark: a pixel paw, in the current colour. */
export function PixelPaw({ className }: { className?: string }) {
  const rows = ["...##.##...", "...##.##...", ".##.....##.", ".##.....##.", "....###....", "...#####...", "..#######..", "..#######..", "...##.##..."]
  let d = ""
  rows.forEach((row, y) => {
    for (let x = 0; x < row.length; x++) {
      if (row[x] !== "#") continue
      let n = 1
      while (row[x + n] === "#") n++
      d += `M${x} ${y}h${n}v1h-${n}z`
      x += n - 1
    }
  })
  return (
    <svg className={cn("pixel pixel-paw", className)} viewBox="0 0 11 9" shapeRendering="crispEdges" aria-hidden="true" focusable="false">
      <path d={d} fill="currentColor" />
    </svg>
  )
}

/** A small pixel heart, from the Mac app's petting heart. */
export function PixelHeart({ className }: { className?: string }) {
  return (
    <svg className={cn("pixel", className)} viewBox="0 0 7 6" shapeRendering="crispEdges" aria-hidden="true" focusable="false">
      <path d="M1 0h2v1h-2zM4 0h2v1h-2zM0 1h7v2h-7zM1 3h5v1h-5zM2 4h3v1h-3zM3 5h1v1h-1z" fill="#DF5A67" />
      <path d="M1 1h1v1h-1z" fill="#F6B3BA" />
    </svg>
  )
}
