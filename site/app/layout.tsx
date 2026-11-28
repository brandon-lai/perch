import type { Metadata, Viewport } from "next"
import { Bricolage_Grotesque, Manrope } from "next/font/google"
import Link from "next/link"
import { PixelPaw } from "@/components/pixel-art"
import { SiteNav } from "@/components/site-nav"
import "./globals.css"

const display = Bricolage_Grotesque({
  subsets: ["latin"],
  weight: ["400", "700"],
  display: "swap",
  variable: "--face-display",
})
const body = Manrope({
  subsets: ["latin"],
  weight: ["400", "600", "700"],
  display: "swap",
  variable: "--face-body",
})

export const metadata: Metadata = {
  metadataBase: new URL("https://perchpet.vercel.app"),
  title: {
    default: "Perch | A red panda for your desktop",
    template: "%s | Perch",
  },
  description:
    "A little pixel red panda for your Mac. It naps on your windows like they’re branches, climbs their edges, and chases your pointer (a stalk of bamboo) when you wake it.",
  openGraph: {
    title: "Perch | A red panda for your desktop",
    description: "It naps on your windows like they’re branches, and plays when you wake it.",
    images: [
      {
        url: "/opengraph-image",
        width: 1200,
        height: 630,
        alt: "Perch, a little pixel red panda sitting on a blue window sill.",
      },
    ],
  },
  twitter: { card: "summary_large_image", images: ["/opengraph-image"] },
}

export const viewport: Viewport = {
  themeColor: "#fdf6ef",
  colorScheme: "light",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className={`${display.variable} ${body.variable}`}>
      <body>
        <a className="skip-link" href="#main">
          Skip to content
        </a>
        <header className="site-header shell">
          <Link href="/" className="wordmark" aria-label="Perch home">
            <PixelPaw />
            perch
          </Link>
          <SiteNav />
        </header>
        {children}
        <footer className="site-footer shell">
          <p className="footer-brand">
            <PixelPaw />
            A little company. Nothing to keep up with.
          </p>
          <nav aria-label="Footer">
            <Link href="/help">Help</Link>
            <Link href="/privacy">Privacy</Link>
            <a href="https://github.com/brandon-lai/perch">Source</a>
          </nav>
        </footer>
      </body>
    </html>
  )
}
