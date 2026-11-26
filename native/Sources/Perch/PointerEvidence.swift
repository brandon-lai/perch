import AppKit
import PerchCore

@MainActor
extension AppController {
    /// The bamboo pointer, for real: WindowServer's arrow becomes the stalk, gets shorter as it's eaten, and the
    /// user's own arrow comes back exactly when it's put away, at launch after a crash, and from the guard when
    /// Perch is killed outright. The pointer changes for a few seconds; nothing on screen is captured.
    func verifyPointer(folder: URL) async throws {
        guard let api = CursorAPI.shared else {
            try writeReport(["available": false], to: folder.appendingPathComponent("pointer-evidence.json"))
            print("Bamboo pointer: cursor registration unavailable on this Mac; Perch draws the stalk beside the arrow.")
            return
        }
        let names = PointerSkin.arrows
        // A running Perch may already have made the arrow bamboo; its saved originals are the real ones.
        let originals = names.map { name -> CursorAPI.Cursor? in
            guard let current = api.read(name) else { return nil }
            return PointerSkin.isBamboo(current) ? api.read(PointerSkin.savedPrefix + name) : current
        }
        guard originals.allSatisfy({ $0 != nil }) else { throw EvidenceError.fixture("the system arrows could not be read") }
        let prints = originals.map { $0!.fingerprint }
        func arrowsAreOriginal() -> Bool { names.enumerated().allSatisfy { api.read($1)?.fingerprint == prints[$0] } }
        func arrowsAreBamboo() -> Bool { names.allSatisfy { api.read($0).map(PointerSkin.isBamboo) ?? false } }
        func onScreen() -> CGSize? { api.displayed()?.size }
        defer { if !arrowsAreOriginal() { for (i, name) in names.enumerated() { api.write(name, originals[i]!) } } }
        var cases: [String: Bool] = [:]

        let skin = PointerSkin()
        let pointerWasArrow = onScreen() == originals[0]!.size
        cases["becomesTheStalk"] = skin.show(length: Bamboo.fullLength, scale: 1.5) && arrowsAreBamboo()
        let stalk = api.read(names[0])!
        cases["tipIsTheHotspot"] = stalk.size == CGSize(width: 21, height: 36) && abs(stalk.hotspot.x - 14.25) < 0.01 &&
            abs(stalk.hotspot.y - 2.25) < 0.01 && stalk.images.map(\.width) == [21, 42, 105, 210]
        cases["savesTheRealArrowsForLater"] = names.enumerated().allSatisfy { api.read(PointerSkin.savedPrefix + $1)?.fingerprint == prints[$0] }
        try await Task.sleep(nanoseconds: 150_000_000)
        // Only checkable when the pointer was showing the arrow (not a text cursor) as it changed.
        let shownStalk = onScreen()
        if pointerWasArrow { cases["pointerOnScreenIsTheStalk"] = shownStalk == stalk.size }
        cases["eatenShorter"] = skin.show(length: 9, scale: 1.5) && api.read(names[0])?.fingerprint != stalk.fingerprint && arrowsAreBamboo()
        cases["nearlyGoneIsTheArrow"] = !skin.show(length: 2, scale: 1.5) && arrowsAreOriginal()
        _ = skin.show(length: Bamboo.fullLength, scale: 2)
        skin.hide()
        cases["putAwayRestoresTheArrowExactly"] = arrowsAreOriginal() &&
            names.allSatisfy { api.read(PointerSkin.savedPrefix + $0) == nil }
        try await Task.sleep(nanoseconds: 150_000_000)
        if pointerWasArrow { cases["pointerOnScreenIsTheArrowAgain"] = onScreen() == originals[0]!.size }

        // A Perch that died without tidying up: the next launch puts the arrow back.
        let crashed = PointerSkin()
        _ = crashed.show(length: Bamboo.fullLength, scale: 1)
        crashed.abandon()
        let leftBamboo = arrowsAreBamboo()
        PointerSkin.recover()
        cases["launchRecoversALeftoverStalk"] = leftBamboo && arrowsAreOriginal() &&
            names.allSatisfy { api.read(PointerSkin.savedPrefix + $0) == nil }

        // Killed outright: the guard notices and puts the arrow back.
        let drill = Process()
        drill.executableURL = Bundle.main.executableURL
        drill.arguments = ["--pointer-crash-drill"]
        drill.standardOutput = FileHandle.nullDevice; drill.standardError = FileHandle.nullDevice
        try drill.run()
        var sawStalk = false
        for _ in 0..<40 where drill.isRunning { if arrowsAreBamboo() { sawStalk = true }; try await Task.sleep(nanoseconds: 50_000_000) }
        drill.waitUntilExit()
        var recovered = false
        for _ in 0..<60 where !recovered { recovered = arrowsAreOriginal(); if !recovered { try await Task.sleep(nanoseconds: 100_000_000) } }
        cases["guardRestoresAfterAKill"] = sawStalk && drill.terminationReason == .uncaughtSignal && recovered

        try writeReport(["available": true, "cases": cases, "pointerWasArrow": pointerWasArrow],
                        to: folder.appendingPathComponent("pointer-evidence.json"))
        let failed = cases.filter { !$0.value }.map(\.key).sorted()
        guard failed.isEmpty else { throw EvidenceError.fixture("bamboo pointer: \(failed.joined(separator: ", "))") }
        print("Bamboo pointer verified: \(cases.count) checks with WindowServer's real arrow (restored exactly).")
    }
}
