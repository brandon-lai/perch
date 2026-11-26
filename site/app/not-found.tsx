import Link from "next/link"
export default function NotFound() {
  return (
    <main id="main" className="document-page shell">
      <h1>No perch here.</h1>
      <p>This page has wandered off. Your little companion is back home.</p>
      <Link className="action primary" href="/">
        Go back to Perch
      </Link>
    </main>
  )
}
