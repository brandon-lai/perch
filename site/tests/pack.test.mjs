import test from "node:test"
import assert from "node:assert/strict"
import { ANIMATIONS, RED_PANDA_COLORS, SAMPLE_PET, createPack, packFilename } from "../lib/pack.ts"
import { pandaPalette, rgba, hex } from "../lib/pixel.ts"

test("red panda packs keep their colors across all nineteen declared actions", () => {
  const pack = createPack({ ...SAMPLE_PET, name: "  Mochi  ", coat: "#B9532A" })
  assert.equal(pack.name, "Mochi")
  assert.equal(pack.species, "redPanda")
  assert.equal(pack.coat, "#B9532A")
  assert.equal(pack.ears, "pointed")
  assert.equal(pack.marking, "none")
  assert.deepEqual(pack.animations.map((animation) => animation.name), [...ANIMATIONS])
  assert.equal(pack.animations.find((animation) => animation.name === "sleep").frameCount, 1)
  assert.ok(pack.animations.every((animation) => animation.fps <= 30 && animation.anchor.y === 0))
  assert.deepEqual(
    { coat: SAMPLE_PET.coat, earColor: SAMPLE_PET.earColor, markingColor: SAMPLE_PET.markingColor },
    RED_PANDA_COLORS
  )
})
test("names, colors and other animals cannot create an invalid native pack", () => {
  assert.throws(() => createPack({ ...SAMPLE_PET, name: "  " }), /name/)
  assert.throws(() => createPack({ ...SAMPLE_PET, name: "a".repeat(41) }), /name/)
  assert.throws(() => createPack({ ...SAMPLE_PET, coat: "url(https://example.com)" }), /color/)
  assert.throws(() => createPack({ ...SAMPLE_PET, species: "dog" }), /not supported/)
  assert.throws(() => createPack({ ...SAMPLE_PET, marking: "socks" }), /not supported/)
})
test("export names cannot create paths or depend on Latin names", () => {
  assert.equal(packFilename("../../Maple"), "Maple.perchpack")
  assert.equal(packFilename("米米"), "my-red-panda.perchpack")
})
test("export selects the pack schema and never copies unexpected source data", () => {
  const pack = createPack({ ...SAMPLE_PET, photos: ["private-reference.png"], remoteURL: "https://example.com/private" })
  assert.ok(!("photos" in pack))
  assert.ok(!("remoteURL" in pack))
})
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
