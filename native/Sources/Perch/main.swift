import AppKit
import PerchCore

// A guard for the bamboo pointer: waits for its Perch to exit and puts the arrow back. No app, no windows.
if let index = CommandLine.arguments.firstIndex(of: "--pointer-guard"), CommandLine.arguments.indices.contains(index + 1),
   let pid = pid_t(CommandLine.arguments[index + 1]) {
    PointerGuard.run(watching: pid)
}
// Evidence only: turn the arrow to bamboo (starting the guard), then die without tidying up.
if CommandLine.arguments.contains("--pointer-crash-drill") {
    MainActor.assumeIsolated { _ = PointerSkin().show(length: Bamboo.fullLength, scale: 1.5) }
    usleep(600_000)
    kill(getpid(), SIGKILL)
}
let application = NSApplication.shared
let controller = AppController()
application.delegate = controller
application.run()
