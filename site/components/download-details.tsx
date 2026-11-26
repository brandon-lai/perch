"use client"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"

export function DownloadDetails() {
  return (
    <Dialog>
      <DialogTrigger render={<Button type="button" variant="outline" />}>
        Read installation notes
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Installing the experimental build</DialogTitle>
          <DialogDescription>
            Perch has not been notarized by Apple. This is a testing build, not
            a public-launch installer.
          </DialogDescription>
        </DialogHeader>
        <ol className="install-steps">
          <li>
            Download and unzip the release. Move Perch.app to Applications.
          </li>
          <li>
            Try opening Perch. If macOS blocks it, review the developer and
            source before proceeding.
          </li>
          <li>
            If you choose to trust this build, use System Settings → Privacy
            &amp; Security → Open Anyway. Do not disable Gatekeeper globally.
          </li>
        </ol>
        <p className="fine-print">
          No Screen Recording permission is needed. Accessibility is asked for
          only if you switch on window pushing.
        </p>
      </DialogContent>
    </Dialog>
  )
}
