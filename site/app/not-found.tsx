import Link from "next/link"
import { PixelSprite, pose, zs } from "@/components/pixel-art"
import { buttonVariants } from "@/components/ui/button"

export default function NotFound() {
  return (
    <main id="main" className="document-page shell not-found">
      <span className="not-found-art" aria-hidden="true">
        <PixelSprite grid={pose("sprawl")} scale={4} />
        <PixelSprite grid={zs.grid} palette={zs.palette} scale={2} />
      </span>
      <h1>No perch here.</h1>
      <p className="lede">This page wandered off for a nap. Maple is back home.</p>
      <Link className={buttonVariants({ size: "lg" })} href="/">
        Go back to Perch
      </Link>
    </main>
  )
}
