import test from "node:test"
import assert from "node:assert/strict"
import { ANIMATIONS, SAMPLE_PET, createPack, packFilename, validatePhotos } from "../lib/pack.ts"

test("packs keep palette and markings across all nineteen declared actions", () => {
  const pack = createPack({ ...SAMPLE_PET, name: "  Miso  ", species: "cat", coat: "#121820", marking: "socks", ears: "pointed" })
  assert.equal(pack.name, "Miso")
  assert.equal(pack.coat, "#121820")
  assert.equal(pack.marking, "socks")
  assert.deepEqual(pack.animations.map((animation) => animation.name), [...ANIMATIONS])
  assert.equal(pack.animations.find((animation) => animation.name === "sleep").frameCount, 1)
  assert.ok(pack.animations.every((animation) => animation.fps <= 30 && animation.anchor.y === 0))
  assert.ok(!JSON.stringify(pack).includes("photo"))
})
test("names, colors and unknown traits cannot create an invalid native pack", () => {
  assert.throws(() => createPack({ ...SAMPLE_PET, name: "  " }), /name/)
  assert.throws(() => createPack({ ...SAMPLE_PET, name: "a".repeat(41) }), /name/)
  assert.throws(() => createPack({ ...SAMPLE_PET, coat: "url(https://example.com)" }), /color/)
  assert.throws(() => createPack({ ...SAMPLE_PET, species: "horse" }), /not supported/)
})
test("photos enforce the exact count, type and size boundaries", () => {
  const photo = { type: "image/jpeg", size: 100 }
  assert.doesNotThrow(() => validatePhotos(Array(3).fill(photo)))
  assert.doesNotThrow(() => validatePhotos(Array(10).fill(photo)))
  assert.throws(() => validatePhotos(Array(2).fill(photo)), /3 to 10/)
  assert.throws(() => validatePhotos(Array(11).fill(photo)), /3 to 10/)
  assert.throws(() => validatePhotos(Array(3).fill({ type: "image/heic", size: 100 })), /HEIC/)
  assert.throws(() => validatePhotos(Array(3).fill({ ...photo, size: 0 })), /nonempty/)
  assert.throws(() => validatePhotos(Array(3).fill({ ...photo, size: 15 * 1024 * 1024 + 1 })), /15 MB/)
})
test("export names cannot create paths or depend on Latin names", () => {
  assert.equal(packFilename("../../Milo"), "Milo.perchpack")
  assert.equal(packFilename("米米"), "my-pet.perchpack")
})

test("export selects the pack schema and never copies unexpected source data", () => {
  const pack = createPack({ ...SAMPLE_PET, photos: ["private-reference.png"], remoteURL: "https://example.com/private" })
  assert.ok(!("photos" in pack))
  assert.ok(!("remoteURL" in pack))
})
