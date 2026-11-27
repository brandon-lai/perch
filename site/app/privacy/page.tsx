import type { Metadata } from "next"
export const metadata: Metadata = { title: "Privacy" }
export default function Privacy() {
  return (
    <main id="main" className="document-page shell">
      <h1>
        Your desktop.
        <br />
        Your business.
      </h1>
      <p className="lede">A red panda that never phones home.</p>
      <section className="document-section">
        <h2>Nothing to upload.</h2>
        <p>
          The browser pack maker runs entirely in this page. A saved pack
          contains only a name, colors, size, rhythm and animation
          declarations.
        </p>
        <p>
          The Mac app stores its pack and preferences on your Mac. It has no
          account and sends nothing anywhere.
        </p>
      </section>
      <section className="document-section">
        <h2>Windows, not their contents.</h2>
        <p>
          The desktop companion reads window geometry to find surfaces, and the
          pointer’s current position to chase it. It does not read titles,
          capture screenshots, log keystrokes or clicks, or keep any pointer
          history. It moves other windows only if you switch on window pushing.
          It has no account, analytics, email, calendar, microphone, or camera
          integration.
        </p>
        <p>
          Remember to tuck your red panda away before a screen share. Perch cannot
          reliably detect all sharing applications.
        </p>
      </section>
      <section className="document-section">
        <h2>What the site host receives.</h2>
        <p>
          Vercel hosts this site and may process ordinary network request data,
          including IP addresses, under its own hosting policies. The
          application does not add tracking cookies or store uploaded files.
          Google Fonts are self-hosted at build time.
        </p>
        <p>
          GitHub hosts the source and release downloads. Visiting those links
          makes a request to GitHub. No cloud generation provider is connected.
        </p>
      </section>
      <section className="document-section">
        <h2>Remove what you made.</h2>
        <p>
          Use the Mac app’s Delete saved pet control to remove its pack and
          preferences. Delete exported packs wherever you saved them. There is
          no server account to delete.
        </p>
      </section>
    </main>
  )
}
