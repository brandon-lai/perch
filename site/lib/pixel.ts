// Mirrors native/Sources/PerchCore/PixelArt.swift, so the site's red panda matches the Mac app pixel for pixel.

export type RGB = [number, number, number]

const clamp = (v: number) => Math.min(Math.max(v, 0), 1)

export function hex(value: string): RGB {
  const v = parseInt(value.replace("#", ""), 16)
  if (!/^#[0-9a-f]{6}$/i.test(value) || Number.isNaN(v)) return [0xc5, 0x8b, 0x55]
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255]
}

function toHSV([r, g, b]: RGB): [number, number, number] {
  const rf = r / 255, gf = g / 255, bf = b / 255
  const mx = Math.max(rf, gf, bf), d = mx - Math.min(rf, gf, bf)
  let h = 0
  if (d > 0) {
    if (mx === rf) h = (gf - bf) / d
    else if (mx === gf) h = (bf - rf) / d + 2
    else h = (rf - gf) / d + 4
    h /= 6
    if (h < 0) h += 1
  }
  return [h, mx === 0 ? 0 : d / mx, mx]
}

function fromHSV(h: number, s: number, v: number): RGB {
  const hue = (((h % 1) + 1) % 1) * 6
  s = clamp(s); v = clamp(v)
  const f = hue - Math.floor(hue), p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
  const rgb = [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][Math.floor(hue) % 6]
  return rgb.map((c) => Math.round(c * 255)) as RGB
}

const light = (c: RGB) => { const [h, s, v] = toHSV(c); return fromHSV(h + 0.012, s * 0.85, v + 0.11) }
const shade = (c: RGB) => { const [h, s, v] = toHSV(c); return fromHSV(h - 0.015, s * 1.08 + 0.04, v * 0.8) }
const far = (c: RGB) => { const [h, s, v] = toHSV(c); return fromHSV(h - 0.025, s * 1.12 + 0.06, v * 0.66) }
const softShade = (c: RGB) => { const [h, s, v] = toHSV(c); return fromHSV(h - 0.01, s * 1.1 + 0.05, v * 0.87) }
const mix = (a: RGB, b: RGB, t: number) => a.map((x, i) => Math.round(x * (1 - t) + b[i] * t)) as RGB
const luminance = ([r, g, b]: RGB) => (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255

export type Palette = {
  colors: Record<string, RGB>
  outline: RGB
  softOutline: RGB
  softChars: Set<string>
  post: Set<string>
}

/** The red panda palette from a pack's coat, legs-and-ears and face-mask colors. */
export function pandaPalette(coatHex: string, earHex: string, markHex: string): Palette {
  const coat = hex(coatHex), ear = hex(earHex), mark = hex(markHex)
  const markShade = softShade(mark)
  const outline = mix(ear, hex("#2B1A2A"), 0.6)
  const ring = mix(shade(coat), ear, 0.3)
  const fixed = (h: string) => hex(h)
  const colors: Record<string, RGB> = {
    h: light(coat), c: coat, s: shade(coat), e: coat, d: shade(coat), r: coat,
    "1": ear, w: ear, "2": shade(ear), v: shade(ear), z: far(ear), F: far(ear),
    // The lit top edge of a climbing leg, warmed toward the coat.
    Z: mix(ear, shade(coat), 0.45),
    u: mark, U: markShade, f: mark, T: ring, "5": ring,
    o: outline, k: fixed("#2B1F22"), j: fixed("#2B1F22"), i: fixed("#FFFAF0"), q: fixed("#6E5D60"),
    V: fixed("#B9A7B8"), p: fixed("#E48C8C"), P: fixed("#C46B70"), m: fixed("#5A2E33"), x: fixed("#B9B3AB"),
    H: fixed("#DF5A67"), I: fixed("#F6B3BA"), B: fixed("#D9473B"), C: fixed("#F59A84"),
    A: fixed("#D9473B"), E: fixed("#A8312F"), O: fixed("#F59A84"), J: fixed("#74B347"), Q: fixed("#5B3A26"),
  }
  const soft = luminance(mark) > luminance(coat) + 0.15 ? new Set(["u", "U"]) : new Set<string>()
  return { colors, outline, softOutline: mix(markShade, outline, 0.45), softChars: soft, post: new Set(["x"]) }
}

export function fixedPalette(colors: Record<string, string>, outline: string): Palette {
  const parsed = Object.fromEntries(Object.entries(colors).map(([k, v]) => [k, hex(v)]))
  return { colors: parsed, outline: hex(outline), softOutline: hex(outline), softChars: new Set(), post: new Set() }
}

/** Top-down RGBA bytes with a one-pixel outline, softened where it only touches the face mask. */
export function rgba(grid: readonly string[], palette: Palette): Uint8ClampedArray {
  const height = grid.length, width = grid[0]?.length ?? 0
  const out = new Uint8ClampedArray(width * height * 4)
  const at = (x: number, y: number) => (x >= 0 && y >= 0 && x < width && y < height ? grid[y][x] : ".")
  const solid = (x: number, y: number) => { const ch = at(x, y); return ch === "." || palette.post.has(ch) ? null : ch }
  const put = (x: number, y: number, c: RGB) => { const i = (y * width + x) * 4; out[i] = c[0]; out[i + 1] = c[1]; out[i + 2] = c[2]; out[i + 3] = 255 }
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const ch = solid(x, y)
      if (ch) { put(x, y, palette.colors[ch] ?? palette.outline); continue }
      const near = [solid(x + 1, y), solid(x - 1, y), solid(x, y + 1), solid(x, y - 1)].filter((n): n is string => n !== null)
      if (!near.length) continue
      put(x, y, near.every((n) => palette.softChars.has(n)) ? palette.softOutline : palette.outline)
    }
  }
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) if (palette.post.has(at(x, y))) put(x, y, palette.colors[at(x, y)] ?? palette.outline)
  return out
}
