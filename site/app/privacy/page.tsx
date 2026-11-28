import type { Metadata } from "next"
import { PixelSprite, pose } from "@/components/pixel-art"

export const metadata: Metadata = { title: "Privacy" }

export default function Privacy() {
  return (
    <main id="main" className="document-page shell">
      <PixelSprite className="page-sprite" grid={pose("sprawl")} scale={3} />
      <h1>Your desktop. Your business.</h1>
      <p className="lede">A red panda that never phones home.</p>

      <section className="document-section">
        <h2>Nothing to upload.</h2>
        <p>
          The Mac app keeps its name and settings on your Mac. It has no account and sends nothing anywhere. This site
          has no sign-in and nothing to upload.
        </p>
      </section>

      <section className="document-section">
        <h2>Windows, not their contents.</h2>
        <p>
          The desktop companion reads window positions and sizes to find surfaces, and the pointer’s current position
          to chase it. It does not read titles, capture screenshots, log keystrokes or clicks, or keep any pointer
          history. It moves other windows only if you switch on window pushing. It has no account, analytics, email,
          calendar, microphone, or camera integration.
        </p>
        <p>Remember to tuck your red panda away before a screen share. Perch can’t reliably detect every sharing app.</p>
      </section>

      <section className="document-section">
        <h2>What the site host receives.</h2>
        <p>
          Vercel hosts this site and may process ordinary network request data, including IP addresses, under its own
          hosting policies. The site adds no tracking cookies and stores no files. Fonts are self-hosted at build time.
        </p>
        <p>
          GitHub hosts the source and release downloads. Visiting those links makes a request to GitHub. No cloud
          generation provider is connected.
        </p>
      </section>

      <section className="document-section">
        <h2>Starting over.</h2>
        <p>
          In the Mac app, Settings → Reset Perch… removes its name and settings from your Mac. There’s no server
          account to delete.
        </p>
      </section>
    </main>
  )
}
