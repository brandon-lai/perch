import type { Metadata } from "next"
export const metadata: Metadata = { title: "Privacy" }
export default function Privacy() {
  return (
    <main id="main" className="document-page shell">
      <h1>
        Your pet.
        <br />
        Your photos.
      </h1>
      <p className="lede">Personal does not have to mean uploaded.</p>
      <section className="document-section">
        <h2>Photos stay with you.</h2>
        <p>
          The browser builder opens photos locally as references. It does not
          upload them. Close the page or remove the photos to release them from
          memory. A saved pet pack contains only a name, traits, colors, and
          animation declarations.
        </p>
        <p>
          The Mac app processes photos locally. It stores the pet pack and
          preferences on your Mac. Source photos are not copied into the pack.
          Your original files remain yours.
        </p>
      </section>
      <section className="document-section">
        <h2>Windows, not their contents.</h2>
        <p>
          The desktop companion reads window geometry to find surfaces. It does
          not read titles, capture screenshots, log keystrokes, or move other
          windows. It has no account, analytics, email, calendar, microphone, or
          camera integration.
        </p>
        <p>
          Remember to send your pet to bed before a screen share. Perch cannot
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
          makes a request to GitHub. No cloud pet-generation provider is
          connected.
        </p>
      </section>
      <section className="document-section">
        <h2>Remove what you made.</h2>
        <p>
          Use the Mac app’s reset controls to remove the saved pet and
          preferences. Delete exported packs wherever you saved them. In the
          browser, remove local photos or close the tab. There is no server
          account to delete.
        </p>
      </section>
    </main>
  )
}
