import type { Metadata } from "next"
import { PetBuilder } from "@/components/pet-builder"
export const metadata: Metadata = {
  title: "Make your pet",
  description:
    "Make a consistent little companion from your pet’s colors and markings. Your photos stay in this browser.",
}
export default function Make() {
  return (
    <main id="main" className="builder-page shell">
      <PetBuilder />
    </main>
  )
}
