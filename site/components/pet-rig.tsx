"use client"

import { useEffect, useMemo, useRef, useState } from "react"
import type { PetTraits, Pose } from "@/lib/pack"
import { pandaPalette, rgba } from "@/lib/pixel"
import art from "@/lib/panda-art.json"

type Animation = { frames: string[][]; slots: number[] }
const POSES = art.poses as unknown as Record<string, Animation>

/** Art pixels per CSS pixel on the site, by size. The Mac app draws it at 1–2 points per pixel. */
export const RIG_SCALE = { small: 3, medium: 4, large: 5 } as const

/**
 * The red panda from the Mac app's own sprite grids, recolored with the same palette rules. Its paws rest on the
 * bottom edge. Only its opaque pixels take clicks, like the desktop overlay.
 */
export function PetRig({
  traits,
  pose = "idle",
  still = false,
}: {
  traits: PetTraits
  pose?: Pose
  still?: boolean
}) {
  const canvas = useRef<HTMLCanvasElement>(null)
  const animation = POSES[pose] ?? POSES.idle
  const palette = useMemo(
    () => pandaPalette(traits.coat, traits.earColor, traits.markingColor),
    [traits.coat, traits.earColor, traits.markingColor]
  )
  const frames = useMemo(() => animation.frames.map((frame) => rgba(frame, palette)), [animation, palette])
  const [slot, setSlot] = useState(0)
  const [reduced, setReduced] = useState(false)
  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)")
    const sync = () => setReduced(query.matches)
    sync()
    query.addEventListener("change", sync)
    return () => query.removeEventListener("change", sync)
  }, [])
  useEffect(() => {
    if (still || reduced) return
    const timer = window.setInterval(() => setSlot((value) => (value + 1) % 12), 1000 / 12)
    return () => window.clearInterval(timer)
  }, [still, reduced, pose])
  const shown = still || reduced ? 0 : slot
  const index = animation.slots[shown] ?? 0
  const pixels = frames[index]
  // Most frames are 32 pixels square; climbing frames are larger.
  const height = animation.frames[index]?.length ?? art.side
  const width = animation.frames[index]?.[0]?.length ?? art.side
  useEffect(() => {
    const context = canvas.current?.getContext("2d")
    if (!context || !pixels) return
    context.putImageData(new ImageData(new Uint8ClampedArray(pixels), width, height), 0, 0)
  }, [pixels, width, height])
  const scale = RIG_SCALE[traits.size]
  // An invisible outline of this frame's opaque pixels takes the clicks, so transparent corners pass through.
  const mask = useMemo(() => {
    if (!pixels) return ""
    let d = ""
    for (let y = 0; y < height; y++) {
      let x = 0
      while (x < width) {
        if (pixels[(y * width + x) * 4 + 3] === 0) { x++; continue }
        const start = x
        while (x < width && pixels[(y * width + x) * 4 + 3] > 0) x++
        d += `M${start} ${y}h${x - start}v1h-${x - start}z`
      }
    }
    return d
  }, [pixels, width, height])
  return (
    <span
      className={`pet-rig pose-${pose} ${still ? "pet-still" : ""}`}
      style={{ width: width * scale, height: height * scale }}
      role="img"
      aria-label={`${traits.name}, red panda, ${pose}`}
    >
      <canvas ref={canvas} width={width} height={height} aria-hidden="true" />
      <svg viewBox={`0 0 ${width} ${height}`} aria-hidden="true">
        <g>
          <path d={mask} fill="transparent" />
        </g>
      </svg>
    </span>
  )
}

