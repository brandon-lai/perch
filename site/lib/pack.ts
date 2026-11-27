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
/** Perch is one red panda in one look: the Mac app's colors. */
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
