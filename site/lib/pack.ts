export const ANIMATIONS = [
  "idle",
  "walk",
  "sit",
  "sleep",
  "fall",
  "ride",
  "held",
  "react",
  "climb",
  "pet",
  "feed",
  "play",
  "sniff",
  "stretch",
  "yawn",
  "shake",
  "look",
  "highFive",
  "peek",
] as const
export type Pose = (typeof ANIMATIONS)[number]
export type PetTraits = {
  name: string
  species: "dog" | "cat"
  coat: string
  earColor: string
  markingColor: string
  marking: "none" | "chest" | "socks" | "tuxedo"
  ears: "floppy" | "pointed"
  size: "small" | "medium" | "large"
  temperament: "calm" | "curious"
  remembrance: boolean
}
export type PetPack = PetTraits & {
  schemaVersion: 1
  rigVersion: "perch-1"
  animations: {
    name: Pose
    frameCount: number
    fps: number
    loop: "loop" | "once" | "hold"
    anchor: { x: number; y: number }
  }[]
}
export const SAMPLE_PET: PetTraits = {
  name: "Milo",
  species: "dog",
  coat: "#C58B55",
  earColor: "#875C43",
  markingColor: "#F2EDE4",
  marking: "chest",
  ears: "floppy",
  size: "medium",
  temperament: "curious",
  remembrance: false,
}

export function createPack(traits: PetTraits): PetPack {
  const name = traits.name.trim()
  if (!name || name.length > 40)
    throw new Error("Give your pet a name between 1 and 40 characters.")
  for (const color of [traits.coat, traits.earColor, traits.markingColor]) {
    if (!/^#[0-9a-f]{6}$/i.test(color))
      throw new Error("Choose a valid coat, ear, and marking color.")
  }
  if (
    !["dog", "cat"].includes(traits.species) ||
    !["none", "chest", "socks", "tuxedo"].includes(traits.marking) ||
    !["floppy", "pointed"].includes(traits.ears) ||
    !["small", "medium", "large"].includes(traits.size) ||
    !["calm", "curious"].includes(traits.temperament) ||
    typeof traits.remembrance !== "boolean"
  ) {
    throw new Error("A pet trait is not supported by this rig.")
  }
  return {
    name,
    species: traits.species,
    coat: traits.coat,
    earColor: traits.earColor,
    markingColor: traits.markingColor,
    marking: traits.marking,
    ears: traits.ears,
    size: traits.size,
    temperament: traits.temperament,
    remembrance: traits.remembrance,
    schemaVersion: 1,
    rigVersion: "perch-1",
    animations: ANIMATIONS.map((pose) => ({
      name: pose,
      frameCount: pose === "sleep" ? 1 : 12,
      fps: 12,
      loop: ["idle", "walk", "sleep", "ride", "held", "sniff", "look"].includes(
        pose
      )
        ? "loop"
        : "once",
      anchor: { x: 0.5, y: 0 },
    })),
  }
}

export function validatePhotos(
  files: readonly { type: string; size: number }[]
) {
  if (files.length < 3 || files.length > 10)
    throw new Error(
      "Choose 3 to 10 photos: a side view, a front view, and a face."
    )
  if (
    files.some(
      (file) => !["image/jpeg", "image/png", "image/webp"].includes(file.type)
    )
  )
    throw new Error(
      "Use JPG, PNG, or WebP photos. Convert HEIC photos to JPG first."
    )
  if (files.some((file) => file.size === 0 || file.size > 15 * 1024 * 1024))
    throw new Error("Each photo must be nonempty and under 15 MB.")
}

export function packFilename(name: string) {
  return `${
    name
      .normalize("NFKD")
      .replace(/[^a-z0-9]+/gi, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 40) || "my-pet"
  }.perchpack`
}
