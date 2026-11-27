import test from "node:test"
import assert from "node:assert/strict"
import { SAMPLE_PET } from "../lib/pack.ts"
import { pandaPalette, rgba, hex } from "../lib/pixel.ts"

test("the site's palette dresses the Mac app's sprite grids the same way", () => {
  const palette = pandaPalette(SAMPLE_PET.coat, SAMPLE_PET.earColor, SAMPLE_PET.markingColor)
  assert.deepEqual(palette.colors.c, hex(SAMPLE_PET.coat))
  assert.deepEqual(palette.colors["1"], hex(SAMPLE_PET.earColor))
  assert.deepEqual(palette.colors.u, hex(SAMPLE_PET.markingColor))
  const pixels = rgba([".....", ".u.c.", "....."], palette)
  const at = (x, y) => Array.from(pixels.slice((y * 5 + x) * 4, (y * 5 + x) * 4 + 4))
  assert.deepEqual(at(1, 1), [...hex(SAMPLE_PET.markingColor), 255])
  assert.deepEqual(at(0, 1), [...palette.softOutline, 255], "the cream mask keeps a soft edge")
  assert.deepEqual(at(2, 1), [...palette.outline, 255], "edges shared with fur stay dark")
  assert.equal(at(0, 0)[3], 0, "corners stay transparent")
})
test("the site's palette port matches the Mac app's palette slot for slot", async () => {
  const { default: art } = await import("../lib/panda-art.json", { with: { type: "json" } })
  const native = art.maplePalette
  const palette = pandaPalette(SAMPLE_PET.coat, SAMPLE_PET.earColor, SAMPLE_PET.markingColor)
  for (const [slot, value] of Object.entries(native.colors)) {
    assert.deepEqual(palette.colors[slot], hex(value), `slot ${slot}`)
  }
  assert.deepEqual(palette.outline, hex(native.outline))
  assert.deepEqual(palette.softOutline, hex(native.softOutline))
})
