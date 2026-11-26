import AppKit
import SpriteKit
import PerchCore

enum EvidenceError: LocalizedError {
    case noScreen, noBitmap, output, fixture(String), emptyCapture
    var errorDescription: String? {
        switch self {
        case .noScreen: "A logged-in graphical macOS session is required."
        case .noBitmap: "The owned native view could not create a rendered bitmap."
        case .output: "Run from native/ and use an output path inside native/."
        case .fixture(let detail): "Fixture failed: \(detail)"
        case .emptyCapture: "Capture was uniform or the view never rendered."
        }
    }
}
@MainActor
extension AppController {
    func runEvidence(arguments: [String]) {
        Task { @MainActor in
            do {
                let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true).standardizedFileURL
                guard root.lastPathComponent == "native" else { throw EvidenceError.output }
                let folder: URL
                if let index = arguments.firstIndex(of: "--output"), arguments.indices.contains(index + 1) {
                    folder = URL(fileURLWithPath: arguments[index + 1], relativeTo: root).standardizedFileURL
                } else { folder = root.appendingPathComponent("dist") }
                guard folder.path.hasPrefix(root.path + "/") else { throw EvidenceError.output }
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                if let index = arguments.firstIndex(of: "--verify-pack"), arguments.indices.contains(index + 1) {
                    let input = URL(fileURLWithPath: arguments[index + 1], relativeTo: root).standardizedFileURL
                    guard input.path.hasPrefix(root.path + "/") else { throw EvidenceError.output }
                    let size = try input.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 256 * 1024 else { throw PackError.tooLarge }
                    let pack = try PetPack.decode(Data(contentsOf: input))
                    let encoded = try pack.encoded()
                    guard try PetPack.decode(encoded) == pack else { throw EvidenceError.fixture("pack round trip") }
                    try encoded.write(to: folder.appendingPathComponent("imported-roundtrip.perchpack"), options: .atomic)
                    try writeReport(["schemaVersion": pack.schemaVersion, "rigVersion": pack.rigVersion,
                        "animationCount": pack.animations.count, "roundTripPassed": true,
                        "sourcePhotoFields": 0, "inputBytes": size, "exportBytes": encoded.count
                    ], to: folder.appendingPathComponent("pack-evidence.json"))
                    print("Pack import/export verified: schema 1, perch-1, 19 actions, exact round trip.")
                } else if arguments.contains("--verify-tree") { try await verifyTree(folder: folder) }
                else if arguments.contains("--capture-sprites") { try captureSprites(folder: folder); try captureClimbPoses(folder: folder) }
                else if arguments.contains("--capture-climb-poses") { try captureClimbPoses(folder: folder) }
                else if arguments.contains("--export-site-art") { try exportSiteArt(folder: folder) }
                else if arguments.contains("--verify-mischief") { try await verifyMischief(folder: folder) }
                else if arguments.contains("--verify-climb") { try await verifyClimb(folder: folder) }
                else if arguments.contains("--verify-cursor") { try await verifyCursorPlay(folder: folder) }
                else if arguments.contains("--verify-pointer") { try await verifyPointer(folder: folder) }
                else if arguments.contains("--verify-fixture") { try await verifyFixture(folder: folder) }
                else if arguments.contains("--capture-preview") { try await capturePreview(folder: folder) }
                else { try await captureSettings(folder: folder) }
                NSApp.terminate(nil)
            } catch {
                fputs("Perch verification failed: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
    }
    func ownedWindow(view: NSView, size: NSSize, title: String) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = title; window.isReleasedWhenClosed = false
        window.contentView = view; window.center()
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        // macOS may refuse to activate us while someone is using another app; keep our test window in front anyway.
        window.orderFrontRegardless()
        return window
    }
    func waitForRender() async throws {
        try await Task.sleep(for: .milliseconds(700))
    }
    @discardableResult
    func captureOwned(_ view: NSView, url: URL) throws -> Int {
        view.layoutSubtreeIfNeeded(); view.display()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw EvidenceError.noBitmap }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw EvidenceError.noBitmap }
        var unique = Set<UInt32>()
        for y in Swift.stride(from: 0, to: bitmap.pixelsHigh, by: 5) {
            for x in Swift.stride(from: 0, to: bitmap.pixelsWide, by: 5) {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                    unique.insert(UInt32(color.redComponent * 255) << 16 |
                        UInt32(color.greenComponent * 255) << 8 | UInt32(color.blueComponent * 255))
                }
            }
        }
        guard unique.count > 20 else { throw EvidenceError.emptyCapture }
        try data.write(to: url, options: .atomic)
        print("Rendered own NSView: \(url.path) · \(bitmap.pixelsWide)×\(bitmap.pixelsHigh) · \(unique.count) sampled colors")
        return unique.count
    }
    func writeReport(_ values: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
    }
    func capturePreview(folder: URL) async throws {
        let view = RigPreview(rig: rig)
        view.contactSheet = true; view.phase = 3
        let window = ownedWindow(view: view, size: NSSize(width: 920, height: 730), title: "Perch — shared rig, twelve poses")
        try await waitForRender()
        let colors = try captureOwned(view, url: folder.appendingPathComponent("native-preview.png"))
        try activePack.encoded().write(to: folder.appendingPathComponent("Maple.perchpack"), options: .atomic)
        var cinnamon = PetPack.redPanda(name: "Cinnamon", size: .small)
        cinnamon.coat = "#B9532A"; cinnamon.earColor = "#3A2220"; cinnamon.temperament = .calm
        view.rig = PetRig(pack: cinnamon); view.needsDisplay = true
        try await waitForRender()
        try captureOwned(view, url: folder.appendingPathComponent("native-preview-cinnamon.png"))
        try cinnamon.encoded().write(to: folder.appendingPathComponent("Cinnamon.perchpack"), options: .atomic)
        try writeReport([
            "captureMethod": "NSView.cacheDisplay in our own visible NSApplication window",
            "sampledColors": colors, "visiblePosesPerSheet": 12, "sheets": 2,
            "preGeneratedTexturesPerPet": rig.generatedCount, "manifestActions": Action.allCases.count,
            "otherWindowsCaptured": 0
        ], to: folder.appendingPathComponent("render-evidence.json"))
        window.close()
    }
    func captureSettings(folder: URL) async throws {
        status = "Name your red panda and pick its colors, then choose Save & wake."
        showSettings()
        try await waitForRender()
        guard let content = settingsWindow?.contentView else { throw EvidenceError.noBitmap }
        try captureOwned(content, url: folder.appendingPathComponent("native-settings.png"))
        settingsScrollTarget = "files"
        try await waitForRender()
        scrollOwnedToBottom(content)
        try await waitForRender()
        try captureOwned(content, url: folder.appendingPathComponent("native-settings-files.png"))
        settingsWindow?.close()
    }
    /// On a shared desktop, the app that re-activates as the previous run exits can land in front of our owned
    /// window. Raise ours until the window list shows nothing else over it (up to six seconds).
    func raiseOwned(_ window: NSWindow, ownIDs: Set<UInt32>) async throws {
        let id = UInt32(window.windowNumber)
        for _ in 0..<30 {
            window.orderFrontRegardless()
            tracker.poll(includeOwnIDs: ownIDs)
            let covered = tracker.windows.prefix { $0.id != id }.contains { $0.bounds.intersects(Rect(window.frame)) }
            if !covered && tracker.windows.contains(where: { $0.id == id }) { return }
            try await Task.sleep(for: .milliseconds(200))
        }
    }

    func verifyFixture(folder: URL) async throws {
        guard let screen = NSScreen.screens.first else { throw EvidenceError.noScreen }
        let safe = screen.visibleFrame
        let fixtureView = FixtureView(rig: rig)
        let fixture = ownedWindow(view: fixtureView, size: NSSize(width: 560, height: 320), title: "Perch owned-window physics fixture")
        fixture.setFrameOrigin(NSPoint(x: safe.minX + 100, y: safe.minY + 140))
        try await waitForRender()
        let id = UInt32(fixture.windowNumber)
        let ownIDs: Set<UInt32> = [id]
        rebuildOverlays()
        try await raiseOwned(fixture, ownIDs: ownIDs)
        guard tracker.windows.contains(where: { $0.id == id }) else { throw EvidenceError.fixture("CG did not return our owned window bounds") }
        // Only our fixture influences this test. Existing windows are never photographed or logged.
        func fixtureSurfaces() -> [Surface] {
            Surfaces.build(windows: tracker.windows.filter { ownIDs.contains($0.id) },
                screens: tracker.screens, visible: tracker.visible)
        }
        guard let initial = fixtureSurfaces().first(where: { $0.windowID == id }) else {
            throw EvidenceError.fixture("owned top edge unavailable")
        }
        var pet = PetEngine(position: Point(initial.left + 220, initial.y))
        pet.perch(on: initial, x: initial.left + 220)
        engine = pet; render()
        let initialPosition = engine.position
        var rideCount = 0
        var maxError = 0.0
        for _ in 0..<6 {
            fixture.setFrameOrigin(NSPoint(x: fixture.frame.minX + 14, y: fixture.frame.minY + 3))
            try await Task.sleep(for: .milliseconds(110))
            fixture.orderFrontRegardless()
            tracker.poll(includeOwnIDs: ownIDs)
            pet.tick(dt: 0.1, surfaces: fixtureSurfaces(), screens: tracker.screens,
                rhythm: Rhythm(hour: 12, quietEnabled: false))
            if pet.state == .ride { rideCount += 1 }
            if let surface = pet.support { maxError = max(maxError, abs(pet.position.y - surface.y)) }
            engine = pet; render()
        }
        guard rideCount == 6, maxError < 0.1 else { throw EvidenceError.fixture("slow ride or gravity alignment") }
        fixtureView.lines = ["Slow move: \(rideCount)/6 rides", "Paw alignment error: \(String(format: "%.2f", maxError)) pt"]
        fixtureView.action = .ride; fixtureView.needsDisplay = true
        try await waitForRender()
        try captureOwned(fixtureView, url: folder.appendingPathComponent("native-fixture-ride.png"))
        guard let (overlayPanel, overlayView) = overlays.first(where: { $0.0.frame.contains(NSPoint(x: pet.position.x, y: pet.position.y)) }) else {
            throw EvidenceError.fixture("real overlay display missing")
        }
        let ridingScene = overlayView.petScene!
        let ownRect = fixture.frame.offsetBy(dx: -overlayPanel.frame.minX, dy: -overlayPanel.frame.minY)
        let outline = SKShapeNode(rect: ownRect)
        outline.strokeColor = NSColor(hex: "#ABB8CB")
        outline.lineWidth = 2; outline.fillColor = .clear
        ridingScene.addChild(outline)
        let label = SKLabelNode(text: "Owned window edge · 6 slow rides · no desktop image")
        label.fontName = "Helvetica"; label.fontSize = 13; label.fontColor = NSColor(hex: "#293341")
        label.position = CGPoint(x: ownRect.midX, y: ownRect.maxY - 28); ridingScene.addChild(label)
        let crop = NSRect(x: ownRect.minX - 20, y: ownRect.maxY - 65, width: ownRect.width + 40, height: 210)
        let backdrop = SKShapeNode(rect: crop)
        backdrop.fillColor = NSColor(hex: "#E9EDF5"); backdrop.strokeColor = .clear
        backdrop.zPosition = -100; ridingScene.addChild(backdrop)
        try await waitForRender()
        guard let fullImage = overlayView.texture(from: ridingScene)?.cgImage() else {
            throw EvidenceError.fixture("real riding overlay texture missing")
        }
        let sx = Double(fullImage.width) / Double(ridingScene.size.width)
        let sy = Double(fullImage.height) / Double(ridingScene.size.height)
        let pixelCrop = CGRect(x: Double(crop.minX) * sx, y: Double(ridingScene.size.height - crop.maxY) * sy,
            width: Double(crop.width) * sx, height: Double(crop.height) * sy)
        guard let rideImage = fullImage.cropping(to: pixelCrop),
              let ridePNG = NSBitmapImageRep(cgImage: rideImage).representation(using: .png, properties: [:]) else {
            throw EvidenceError.fixture("real riding overlay render missing")
        }
        try ridePNG.write(to: folder.appendingPathComponent("native-overlay-ride.png"), options: .atomic)
        let renderedOverlayUpdates = ridingScene.updateCount
        let actualOverlayTravel = engine.position.x - initialPosition.x
        guard renderedOverlayUpdates >= 6, abs(actualOverlayTravel - 84) < 0.1 else {
            throw EvidenceError.fixture("actual overlay did not render the ride")
        }
        outline.removeFromParent(); label.removeFromParent(); backdrop.removeFromParent()
        fixture.setFrameOrigin(NSPoint(x: fixture.frame.minX + 110, y: fixture.frame.minY))
        try await Task.sleep(for: .milliseconds(110))
        tracker.poll(includeOwnIDs: ownIDs)
        pet.tick(dt: 0.1, surfaces: fixtureSurfaces(), screens: tracker.screens,
            rhythm: Rhythm(hour: 12, quietEnabled: false))
        let fastFall = pet.state == .fall && pet.support == nil
        guard fastFall else { throw EvidenceError.fixture("fast move did not detach") }
        guard let next = fixtureSurfaces().first(where: { $0.windowID == id }) else {
            throw EvidenceError.fixture("moved window missing")
        }
        pet.perch(on: next, x: next.left + 220)
        fixture.miniaturize(nil)
        try await Task.sleep(for: .milliseconds(800))
        tracker.poll(includeOwnIDs: ownIDs)
        pet.tick(dt: 0.1, surfaces: fixtureSurfaces(), screens: tracker.screens,
            rhythm: Rhythm(hour: 12, quietEnabled: false))
        let minimizedFall = pet.state == .fall && pet.support == nil
        guard minimizedFall else { throw EvidenceError.fixture("minimized target remained supported") }
        fixture.deminiaturize(nil)
        fixture.makeKeyAndOrderFront(nil); fixture.orderFrontRegardless()
        try await waitForRender()
        tracker.poll(includeOwnIDs: ownIDs)
        guard let closed = fixtureSurfaces().first(where: { $0.windowID == id }) else { throw EvidenceError.fixture("restore missing") }
        pet.perch(on: closed, x: closed.left + 220)
        fixture.close()
        try await Task.sleep(for: .milliseconds(400))
        tracker.poll(includeOwnIDs: ownIDs)
        pet.tick(dt: 0.1, surfaces: fixtureSurfaces(), screens: tracker.screens,
            rhythm: Rhythm(hour: 12, quietEnabled: false))
        let vanishedFall = pet.state == .fall
        guard vanishedFall else { throw EvidenceError.fixture("vanished target remained supported") }
        for _ in 0..<120 {
            pet.tick(dt: 1.0 / 30, surfaces: fixtureSurfaces(), screens: tracker.screens,
                rhythm: Rhythm(hour: 12, quietEnabled: false))
        }
        let floorLanding = pet.support?.kind == .floor
        guard floorLanding else { throw EvidenceError.fixture("gravity did not land on safe floor") }
        fixture.makeKeyAndOrderFront(nil); fixture.orderFrontRegardless()
        fixtureView.lines += ["Fast move: Fall ✓", "Minimized / vanished: Fall ✓", "Gravity: landed on safe floor ✓"]
        fixtureView.action = .fall; fixtureView.needsDisplay = true
        try await waitForRender()
        try captureOwned(fixtureView, url: folder.appendingPathComponent("native-fixture-fall.png"))
        // Verify the actual SpriteKit path, not only the bitmap preview.
        let skView = SKView(frame: NSRect(x: 0, y: 0, width: 320, height: 220))
        skView.allowsTransparency = true; skView.preferredFramesPerSecond = 30
        let scene = PetScene(size: skView.frame.size, rig: rig)
        scene.sprite.position = CGPoint(x: 160, y: 35); scene.sprite.setScale(3); scene.selected = .walk
        skView.presentScene(scene)
        let spriteWindow = ownedWindow(view: skView, size: skView.frame.size, title: "Perch SpriteKit renderer fixture")
        try await waitForRender()
        guard let rendered = skView.texture(from: scene)?.cgImage() else { throw EvidenceError.fixture("SpriteKit render unavailable") }
        let spriteBitmap = NSBitmapImageRep(cgImage: rendered)
        guard let png = spriteBitmap.representation(using: .png, properties: [:]) else { throw EvidenceError.noBitmap }
        try png.write(to: folder.appendingPathComponent("native-spritekit.png"), options: .atomic)
        var opaque = 0, transparent = 0, hitAgreements = 0
        let idle = rig.frame(.idle, index: 0)
        var body: (x: Int, y: Int)?
        for y in 0..<RigFrame.side { for x in 0..<RigFrame.side {
            let hit = idle.hit(x: Double(x), y: Double(y))
            if hit { opaque += 1; if body == nil && x >= 12 && y >= 8 { body = (x, y) } } else { transparent += 1 }
        } }
        scene.selected = .idle; scene.frameIndex = 0; scene.refresh()
        // Scene points for one opaque body pixel, an in-sprite transparent corner, and two points beyond the sprite.
        let art = { (x: Double, y: Double) in CGPoint(x: 160 + (x + 0.5 - 16) * 3, y: 35 + (y + 0.5) * 3) }
        let samples = [(art(Double(body?.x ?? 16), Double(body?.y ?? 10)), true), (art(0, 31), false),
                       (CGPoint(x: 25, y: 15), false), (CGPoint(x: 160, y: 210), false)]
        for (p, expected) in samples where scene.alphaHit(p) == expected { hitAgreements += 1 }
        guard opaque > 150, transparent > 300, hitAgreements == 4 else { throw EvidenceError.fixture("alpha hit map") }
        spriteWindow.close()
        fixture.orderFrontRegardless()
        rebuildOverlays()
        // The window server can take a moment to report our window again after another one closes.
        var overlaySurface: Surface?
        try await raiseOwned(fixture, ownIDs: ownIDs)
        for _ in 0..<10 where overlaySurface == nil {
            tracker.poll(includeOwnIDs: ownIDs)
            overlaySurface = fixtureSurfaces().first(where: { $0.windowID == id })
            if overlaySurface == nil { try await Task.sleep(for: .milliseconds(150)) }
        }
        guard let overlaySurface else {
            throw EvidenceError.fixture("overlay target missing")
        }
        engine.perch(on: overlaySurface, x: overlaySurface.left + 220)
        render(mouseOverride: NSPoint(x: engine.position.x + 0.5 * rig.pixelScale, y: engine.position.y + 8.5 * rig.pixelScale))
        let acceptsPet = overlays.contains { !$0.0.ignoresMouseEvents }
        render(mouseOverride: NSPoint(x: safe.minX + 10, y: safe.minY + 10))
        let passesOutside = overlays.allSatisfy { $0.0.ignoresMouseEvents }
        guard acceptsPet && passesOutside else { throw EvidenceError.fixture("overlay pixel event routing") }
        try verifyPointerRouting(folder: folder, surface: overlaySurface,
            outside: NSPoint(x: safe.minX + 10, y: safe.minY + 10))
        bed()
        let bedHidden = overlays.allSatisfy { !$0.0.isVisible && $0.1.isPaused }
        engine.setBed(false); render()
        sleepSystem()
        let lockHidden = overlays.allSatisfy { !$0.0.isVisible && $0.1.isPaused } &&
            timer == nil && mouseMoveMonitor == nil
        locked = false
        registerShortcut()
        guard hotKey != nil && hotKeyHandler != nil, bedHidden, lockHidden else {
            throw EvidenceError.fixture("bed/lock visibility or Carbon shortcut registration")
        }
        for (panel, _) in overlays { panel.close() }
        overlays = []
        try writeReport([
            "platform": ProcessInfo.processInfo.operatingSystemVersionString,
            "boundsReadAPI": "CGWindowListCopyWindowInfo",
            "screenRecordingRequested": false, "accessibilityPermissionRequested": false,
            "windowTitlesOrOwnersLogged": false, "existingWindowContentCaptured": false,
            "ownedWindowSlowMoves": 6, "rideTransitions": rideCount, "maximumPawErrorPoints": maxError,
            "fastMoveFalls": fastFall, "minimizeFalls": minimizedFall, "vanishFalls": vanishedFall,
            "floorLanding": floorLanding, "boundsReadCount": tracker.readCount,
            "actualOverlayRideFramesApplied": rideCount, "actualOverlayHorizontalTravelPoints": actualOverlayTravel,
            "actualOverlaySpriteKitUpdates": renderedOverlayUpdates,
            "aggregateIdleAPIAvailable": aggregateIdleSeconds().isFinite,
            "rideCaptureMethod": "SKView.texture of our real overlay plus owned-window geometry only",
            "spriteKitRenderedPixels": rendered.width * rendered.height,
            "alphaOpaquePixels": opaque, "alphaTransparentPixels": transparent, "alphaHitChecksPassed": hitAgreements,
            "overlayAcceptsPetPixels": acceptsPet, "overlayPassesOtherPixels": passesOutside,
            "bedHidesAndPauses": bedHidden, "simulatedLockHidesAndPauses": lockHidden, "carbonBedShortcutRegistered": hotKey != nil
        ], to: folder.appendingPathComponent("fixture-evidence.json"))
        print("Owned fixture verified: 6 slow rides, fast/minimized/vanished falls, floor landing, SpriteKit render and alpha hits.")
        fixture.close()
    }
    func verifyPointerRouting(folder: URL, surface: Surface, outside: NSPoint) throws {
        engine.perch(on: surface, x: surface.left + 220)
        render(mouseOverride: outside)
        // Art pixel (16, 8 from the bottom) is chest while sitting and back while curled asleep.
        let opaque = NSPoint(x: engine.position.x + 0.5 * rig.pixelScale, y: engine.position.y + 8.5 * rig.pixelScale)
        var suppliedLocation = outside
        guard startPointerMonitoring(currentLocation: { suppliedLocation }), let monitor = mouseMoveMonitor,
              let event = NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
                eventNumber: 0, clickCount: 0, pressure: 0) else {
            throw EvidenceError.fixture("mouse-movement monitors could not register")
        }
        var cases: [String: Bool] = [:]
        cases["idempotentRegistration"] = startPointerMonitoring() && mouseMoveMonitor === monitor
        let boundsReadsBefore = tracker.readCount
        var maximumCallbackMS = 0.0
        func deliver(global: Bool, at point: NSPoint) -> Bool {
            suppliedLocation = point
            let start = ProcessInfo.processInfo.systemUptime
            var unchanged = true
            if global { monitor.handleGlobalMouseMoved() }
            else { unchanged = monitor.handleLocalMouseMoved(event) === event }
            maximumCallbackMS = max(maximumCallbackMS, (ProcessInfo.processInfo.systemUptime - start) * 1000)
            return unchanged
        }
        _ = deliver(global: true, at: opaque)
        cases["awakeGlobalEnterAcceptsPet"] = overlays.contains { !$0.0.ignoresMouseEvents }
        cases["awakeLocalLeavePassesThrough"] = deliver(global: false, at: outside) &&
            overlays.allSatisfy { $0.0.ignoresMouseEvents }
        engine.tick(dt: 0.1, surfaces: [surface], screens: tracker.screens,
            rhythm: Rhythm(hour: 23, idleSeconds: 301))
        render(mouseOverride: outside)
        guard engine.state == .sleep else { throw EvidenceError.fixture("sleeping pointer fixture did not sleep") }
        scheduleTimer(0.25)
        let timerTickBefore = lastTick
        let positionBefore = engine.position
        _ = deliver(global: true, at: opaque)
        cases["sleepGlobalEnterAcceptsImmediately"] = overlays.contains { !$0.0.ignoresMouseEvents }
        cases["sleepLocalLeavePassesImmediately"] = deliver(global: false, at: outside) &&
            overlays.allSatisfy { $0.0.ignoresMouseEvents }
        _ = deliver(global: true, at: NSPoint(x: engine.position.x - 14.5 * rig.pixelScale, y: engine.position.y + 30.5 * rig.pixelScale))
        cases["sleepTransparentSpritePixelsPass"] = overlays.allSatisfy { $0.0.ignoresMouseEvents }
        cases["sleepRemainsPausedWithoutEngineOrTimerTick"] = engine.state == .sleep &&
            engine.position == positionBefore && lastTick == timerTickBefore &&
            overlays.allSatisfy { $0.1.isPaused && $0.1.petScene.isPaused }
        cases["pointerCallbacksDoNotReadWindowMetadata"] = tracker.readCount == boundsReadsBefore
        stopPointerMonitoring()
        suppliedLocation = opaque
        let routingBefore = overlays.map { $0.0.ignoresMouseEvents }
        monitor.handleGlobalMouseMoved()
        _ = monitor.handleLocalMouseMoved(event)
        cases["cleanupIgnoresLateCallbacks"] = !monitor.isActive && mouseMoveMonitor == nil &&
            overlays.map { $0.0.ignoresMouseEvents } == routingBefore
        guard startPointerMonitoring(currentLocation: { suppliedLocation }), let restarted = mouseMoveMonitor else {
            throw EvidenceError.fixture("mouse-movement monitor restart failed")
        }
        _ = applicationShouldTerminate(NSApp)
        cases["terminationRemovesMonitorsAndTimer"] = mouseMoveMonitor == nil && !restarted.isActive && timer == nil
        guard cases.values.allSatisfy({ $0 }) else {
            throw EvidenceError.fixture("pointer routing: " + cases.filter { !$0.value }.keys.sorted().joined(separator: ", "))
        }
        guard startPointerMonitoring(currentLocation: { suppliedLocation }) else {
            throw EvidenceError.fixture("mouse-movement monitors failed to restore for lock cleanup")
        }
        try writeReport([
            "cases": cases, "passedChecks": cases.count,
            "eventMask": ["mouseMoved"], "keyOrClickEventsMonitored": false,
            "eventContentInspected": false, "eventObjectsOrCoordinatesPersisted": false,
            "maximumSynchronousFixtureCallbackMilliseconds": maximumCallbackMS,
            "sleepTimerFallbackSeconds": 0.25,
            "source": "Synthetic owned fixture coordinates through the same global/local callbacks; shared cursor not moved",
            "osGlobalEventDeliveryLatencyMeasured": false
        ], to: folder.appendingPathComponent("pointer-routing-evidence.json"))
        print("Pointer routing verified: \(cases.count) checks; sleeping routing updates without a timer tick; monitors removed on termination.")
    }
    func scrollOwnedToBottom(_ view: NSView) {
        if let scroll = view as? NSScrollView, let document = scroll.documentView,
           document.bounds.height > scroll.contentView.bounds.height {
            let y = document.isFlipped ? document.bounds.maxY - scroll.contentView.bounds.height : document.bounds.minY
            scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        for child in view.subviews { scrollOwnedToBottom(child) }
    }
}
@MainActor
final class FixtureView: NSView {
    let rig: PetRig
    var lines = ["Preparing our own test window…"]
    var action: Action = .sit
    init(rig: PetRig) { self.rig = rig; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("Programmatic views only") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(hex: "#F6F8FC").setFill(); bounds.fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor(hex: "#293341")]
        ("Owned-window verification" as NSString).draw(at: NSPoint(x: 24, y: bounds.height - 38), withAttributes: attrs)
        for (i, line) in lines.enumerated() {
            (line as NSString).draw(at: NSPoint(x: 24, y: bounds.height - 75 - Double(i) * 30), withAttributes: attrs)
        }
        let context = NSGraphicsContext.current!.cgContext
        context.interpolationQuality = .none
        context.draw(rig.frame(action, index: 3).image, in: NSRect(x: bounds.width - 160, y: 24, width: 128, height: 128))
        ("No other window content captured." as NSString).draw(at: NSPoint(x: 24, y: 20),
            withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(hex: "#616B7B")])
    }
}
