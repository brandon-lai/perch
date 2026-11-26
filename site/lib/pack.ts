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
  species: "redPanda"
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
/** Perch is a red panda. Its starting colors match the Mac app's. */
export const RED_PANDA_COLORS = { coat: "#D9772E", earColor: "#5A2F26", markingColor: "#F7EBD3" } as const
export const SAMPLE_PET: PetTraits = {
  name: "Maple",
  species: "redPanda",
  ...RED_PANDA_COLORS,
  marking: "none",
  ears: "pointed",
  size: "medium",
  temperament: "curious",
  remembrance: false,
}

export function createPack(traits: PetTraits): PetPack {
  const name = traits.name.trim()
  if (!name || name.length > 40)
    throw new Error("Give your red panda a name between 1 and 40 characters.")
  for (const color of [traits.coat, traits.earColor, traits.markingColor]) {
    if (!/^#[0-9a-f]{6}$/i.test(color))
      throw new Error("Choose a valid coat, legs-and-ears, and face mask color.")
  }
  if (
    traits.species !== "redPanda" ||
    traits.marking !== "none" ||
    traits.ears !== "pointed" ||
    !["small", "medium", "large"].includes(traits.size) ||
    !["calm", "curious"].includes(traits.temperament) ||
    typeof traits.remembrance !== "boolean"
  ) {
    throw new Error("A trait is not supported by this red panda.")
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

export function packFilename(name: string) {
  return `${
    name
      .normalize("NFKD")
      .replace(/[^a-z0-9]+/gi, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 40) || "my-red-panda"
  }.perchpack`
}
