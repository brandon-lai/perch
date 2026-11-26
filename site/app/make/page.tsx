import type { Metadata } from "next"
import { PetBuilder } from "@/components/pet-builder"
export const metadata: Metadata = {
  title: "Make your red panda",
  description:
    "Name your desktop red panda and pick its colors, then save a pack for Perch for Mac.",
}
export default function Make() {
  return (
    <main id="main" className="builder-page shell">
      <PetBuilder />
    </main>
  )
}
