"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { ArrowDownToLine } from "lucide-react"
import { buttonVariants } from "@/components/ui/button"

/** The header's links, marking the page you're on. */
export function SiteNav() {
  const path = usePathname()
  const current = (href: string) => (path === href ? "page" : undefined)
  return (
    <nav className="site-nav" aria-label="Main navigation">
      <Link className="nav-link" href="/help" aria-current={current("/help")}>
        How it works
      </Link>
      <Link className="nav-link" href="/privacy" aria-current={current("/privacy")}>
        Privacy
      </Link>
      <Link className={buttonVariants({ variant: "outline", size: "sm" })} href="/download" aria-current={current("/download")}>
        <ArrowDownToLine aria-hidden="true" />
        Download
      </Link>
    </nav>
  )
}
