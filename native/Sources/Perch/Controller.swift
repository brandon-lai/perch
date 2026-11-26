import AppKit
import SwiftUI
import SpriteKit
import Carbon
import UniformTypeIdentifiers
import PerchCore

struct Preferences: Codable {
    var calm = false
    var quietEnabled = true
    var quietStart = 22
    var quietEnd = 7
    var homeDisplayID: String?
    var homeCorner: HomeCorner?
    var chewWindows: Bool?
    var pushWindows: Bool?
    var cursorPlay: Bool?
    var bambooPointer: Bool?
    /// Chewing is playful and harmless (marks live in Perch's overlay), so it starts on.
    var chews: Bool { get { chewWindows ?? true } set { chewWindows = newValue } }
    /// Moving other apps' windows needs Accessibility and stays off until chosen.
    var pushes: Bool { get { pushWindows ?? false } set { pushWindows = newValue } }
    /// Red pandas stalk, grab and ride the pointer. It only reads where the pointer is, so it starts on.
    var playsWithCursor: Bool { get { cursorPlay ?? true } set { cursorPlay = newValue } }
    /// A bamboo stalk drawn on the pointer for the red panda to chase and eat.
    var showsBamboo: Bool { get { bambooPointer ?? true } set { bambooPointer = newValue } }
}
struct HomeDisplayChoice: Identifiable {
    let id: String
    let index: Int
    let name: String
}
@MainActor
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
@MainActor
final class OverlayView: SKView {
    weak var controller: AppController?
    var petScene: PetScene!
    let desktopHome = DesktopHomeView()
    var biteViews: [BiteMarkView] = []
    let ball = BallView(frame: .zero)
    let bamboo = BambooView(frame: .zero)
    var down = NSPoint.zero
    var dragged = false
    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let superview, controller?.dragOriginal == nil, desktopHome.bowlHit(point, from: superview) {
            return desktopHome.bowl
        }
        return super.hitTest(point)
    }
    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        guard petScene.alphaHit(local), let controller else { return }
        down = NSEvent.mouseLocation; dragged = false
        controller.beginDrag()
        window?.makeKey(); window?.makeFirstResponder(self)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let controller, controller.dragOriginal != nil else { return }
        let p = NSEvent.mouseLocation
        dragged = dragged || hypot(p.x - down.x, p.y - down.y) > 3
        controller.drag(at: p)
    }
    override func mouseUp(with event: NSEvent) {
        guard let controller, controller.dragOriginal != nil else { return }
        controller.endDrag(clicked: !dragged)
        window?.resignKey()
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { controller?.cancelDrag(); window?.resignKey() }
        else { super.keyDown(with: event) }
    }
    override func rightMouseDown(with event: NSEvent) { controller?.showSettings() }
}
@MainActor
final class AppController: NSObject, ObservableObject, NSApplicationDelegate {
    @Published var draft = PetPack()
    @Published var preferences = Preferences()
    @Published var error: String?
    @Published var status = "Start with Milo, or choose 3–10 photos. Nothing is uploaded."
    @Published var processing = false
    @Published var committed = false
    @Published var previewAction: Action = .idle
    @Published var settingsScrollTarget: String?
    @Published var homeDisplays: [HomeDisplayChoice] = []
    /// Live Accessibility state for the window-pushing setup in Settings.
    @Published var accessibilityTrusted = WindowMover.trusted
    @Published var pushSetupNote: String?
    private var trustTimer: Timer?
    private var trustDeadline = 0.0
    private var testWindow: NSWindow?
    var activePack = PetPack()
    var rig = PetRig(pack: PetPack())
    var engine = PetEngine(position: Point(300, 300))
    var dragOriginal: PetEngine?
    var dragOffset = Point(0, 0)
    let tracker = WindowTracker()
    var overlays: [(OverlayPanel, OverlayView)] = []
    var timer: Timer?
    var lastPoll = 0.0
    var lastTick = 0.0
    var tickInterval = 1.0 / 30
    var locked = false
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var hotKey: EventHotKeyRef?
    var hotKeyHandler: EventHandlerRef?
    var mouseMoveMonitor: MouseMoveMonitor?
    var captureMode = false
    var lastHover = false
    var previewRig: PetRig { rig }
    var biteMarks: [BiteMark] = []
    let windowMover = WindowMover()
    private var trustChecked = -10.0
    var dataDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Perch", isDirectory: true)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        captureMode = args.contains("--capture-preview") || args.contains("--capture-settings") ||
            args.contains("--verify-fixture") || args.contains("--verify-home") || args.contains("--verify-pack") ||
            args.contains("--capture-sprites") || args.contains("--verify-mischief") ||
            args.contains("--verify-climb") || args.contains("--verify-cursor")
        NSApp.setActivationPolicy(.accessory)
        if captureMode { runEvidence(arguments: args); return }
        load()
        setupMenu()
        registerShortcut()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepSystem),
            name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wakeSystem),
            name: NSWorkspace.screensDidWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepSystem),
            name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wakeSystem),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(sleepSystem),
            name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(wakeSystem),
            name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(rebuildOverlays),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        rebuildOverlays()
        startPointerMonitoring()
        if let safe = NSScreen.screens.first?.visibleFrame {
            engine.relocate(Point(safe.midX, safe.minY + 80))
        }
        scheduleTimer(1.0 / 30)
        if !committed || error != nil { showSettings() }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.isFileURL && url.pathExtension.lowercased() == "perchpack" { importPack(url); showSettings() }
            else { error = "Perch opens local .perchpack files only."; showSettings() }
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        saveCareIfNeeded()
        timer?.invalidate()
        timer = nil
        stopPointerMonitoring()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        return .terminateNow
    }
    func load() {
        let packURL = dataDirectory.appendingPathComponent("pet.perchpack")
        if FileManager.default.fileExists(atPath: packURL.path) {
            do {
                // A red panda still in the first default colors picks up the current ones (edited colors stay).
                activePack = try PetPack.decode(Data(contentsOf: packURL)).withCurrentRedPandaColors()
                draft = activePack; rig = PetRig(pack: activePack); committed = true
            } catch { self.error = "Saved pet could not be opened: \(error.localizedDescription). Stock Milo is available." }
        }
        let prefsURL = dataDirectory.appendingPathComponent("preferences.json")
        if FileManager.default.fileExists(atPath: prefsURL.path) {
            do { preferences = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: prefsURL)) }
            catch { self.error = "Saved settings could not be opened: \(error.localizedDescription)." }
        }
        let careURL = dataDirectory.appendingPathComponent("care.json")
        if FileManager.default.fileExists(atPath: careURL.path) {
            do { engine.care = try JSONDecoder().decode(PetCare.self, from: Data(contentsOf: careURL)) }
            catch { self.error = "Saved bowl and appetite could not be opened: \(error.localizedDescription)." }
        }
    }
    private func writeCare() throws {
        try JSONEncoder().encode(engine.care).write(to: dataDirectory.appendingPathComponent("care.json"), options: .atomic)
    }
    private func saveCareIfNeeded() {
        guard committed, !captureMode else { return }
        do { try writeCare() }
        catch {
            self.error = "Could not save bowl and appetite: \(error.localizedDescription)."
            NSLog("Perch: could not save care state: %@", error.localizedDescription)
        }
    }
    func commit() {
        do {
            let pack = try draft.validated()
            if !captureMode {
                try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
                try pack.encoded().write(to: dataDirectory.appendingPathComponent("pet.perchpack"), options: .atomic)
                try JSONEncoder().encode(preferences).write(to: dataDirectory.appendingPathComponent("preferences.json"), options: .atomic)
                try writeCare()
            }
            activePack = pack; draft = pack; rig = PetRig(pack: pack); committed = true
            for (_, view) in overlays { view.petScene.rig = rig; view.petScene.refresh() }
            status = "\(pack.name) is ready. Only traits and settings are saved, never source photos."
            engine.setBed(false)
        } catch { self.error = error.localizedDescription }
    }
    func deletePet() {
        do {
            for file in ["pet.perchpack", "preferences.json", "care.json"] {
                let url = dataDirectory.appendingPathComponent(file)
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }
            activePack = PetPack(); draft = activePack; preferences = Preferences(); rig = PetRig(pack: activePack)
            committed = false; engine.care = PetCare(); engine.setBed(true)
            for (_, view) in overlays { view.petScene.rig = rig }
            status = "Saved pet and settings deleted. Start afresh when you’re ready."
        } catch { self.error = "Could not delete the saved pet: \(error.localizedDescription)." }
    }
    func importPack(_ url: URL) {
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 256 * 1024 else { throw PackError.tooLarge }
            draft = try PetPack.decode(Data(contentsOf: url))
            status = "Imported \(draft.name). Review the traits, then choose Save & wake."
        } catch { self.error = "Pack import failed: \(error.localizedDescription)." }
    }
    func chooseImport() {
        let picker = NSOpenPanel(); picker.allowedContentTypes = [.init(filenameExtension: "perchpack") ?? .json]
        picker.allowsMultipleSelection = false; picker.canChooseDirectories = false
        if picker.runModal() == .OK, let url = picker.url { importPack(url) }
    }
    func exportPack() {
        do {
            let data = try draft.encoded()
            let picker = NSSavePanel()
            picker.nameFieldStringValue = "\(draft.name).perchpack"
            picker.allowedContentTypes = [.init(filenameExtension: "perchpack") ?? .json]
            if picker.runModal() == .OK, let url = picker.url {
                try data.write(to: url, options: .atomic)
                status = "Pack exported. It contains traits and animations, not photos."
            }
        } catch { self.error = "Pack export failed: \(error.localizedDescription)." }
    }
    func choosePhotos() {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.jpeg, .png, .heic, .tiff]
        picker.allowsMultipleSelection = true; picker.canChooseDirectories = false
        picker.message = "Choose 3–10 photos: include a side, front and face view. Photos stay in memory only."
        guard picker.runModal() == .OK else { return }
        let urls = picker.urls
        guard (3...10).contains(urls.count) else { error = PhotoError.count.localizedDescription; return }
        processing = true; status = "Finding foreground colors locally with macOS Vision…"
        Task { @MainActor in
            do {
                let traits = try await Task.detached(priority: .userInitiated) { try PhotoTraits.extract(urls: urls) }.value
                draft.coat = traits.coat; draft.earColor = traits.ear
                status = "Colors suggested from \(traits.count) photos. Check every trait below; foreground may include other objects. Photos were not saved."
            } catch {
                self.error = "Photo analysis failed: \(error.localizedDescription)"
                status = "No photo traits were applied. You can still edit the stock rig and save it."
            }
            processing = false
        }
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 780),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Perch — a little familiar company"
            window.minSize = NSSize(width: 760, height: 680)
            window.isReleasedWhenClosed = false
            window.acceptsMouseMovedEvents = true
            window.contentView = NSHostingView(rootView: SettingsView(controller: self))
            window.center(); settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        refreshTrust()
    }
    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Perch")
        let menu = NSMenu()
        for (name, selector) in [
            ("Wake", #selector(wake)), ("Send to bed  ⌃⌥⌘B", #selector(bed)),
            ("Pet", #selector(pet)), ("Fill food bowl", #selector(feed)), ("Play ball", #selector(play)),
            ("Tidy up bite marks", #selector(tidyBites)),
            ("High five", #selector(highFive)), ("Hop to a window", #selector(hop)),
            ("Peek from menu bar", #selector(peek)), ("Move to next display", #selector(nextDisplay)),
            ("Settings…", #selector(showSettings)), ("Quit Perch", #selector(quit))
        ] {
            let item = NSMenuItem(title: name, action: selector, keyEquivalent: "")
            item.target = self; menu.addItem(item)
        }
        statusItem?.menu = menu
    }
    func registerShortcut() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<AppController>.fromOpaque(context).takeUnretainedValue().bed()
            }
            return noErr
        }
        let handlerResult = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec,
            Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey | cmdKey),
            EventHotKeyID(signature: 0x50524348, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if handlerResult != noErr || result != noErr {
            error = "The bed shortcut could not register (code \(result)). Send to bed remains available in the menu."
        }
    }
    @objc func wake() { engine.setBed(false); scheduleTimer(1.0 / 30) }
    @objc func bed() { engine.setBed(true); dragOriginal = nil; render() }
    @objc func pet() { engine.react(.pet); scheduleTimer(1.0 / 30) }
    @objc func feed() {
        if dragOriginal != nil { cancelDrag() }
        engine.fillBowl(); saveCareIfNeeded()
        render(); scheduleTimer(1.0 / 30)
    }
    @objc func play() {
        if dragOriginal != nil { cancelDrag() }
        engine.startPlay(); scheduleTimer(1.0 / 30)
    }
    @objc func tidyBites() { biteMarks.removeAll(); render() }
    @objc func highFive() { engine.react(.highFive); scheduleTimer(1.0 / 30) }
    @objc func hop() {
        if let surface = engine.windowToClimb(surfaces: tracker.surfaces, screens: tracker.screens, nearbyOnly: false) {
            engine.climb(to: surface); scheduleTimer(1.0 / 30)
        } else { error = "No other perch is within view. Leave some space above a window on your pet’s display, then try Hop again."; showSettings() }
    }
    @objc func peek() {
        if let surface = tracker.surfaces.first(where: { $0.kind == .menu }) {
            engine.climb(to: surface)
            scheduleTimer(1.0 / 30)
        }
    }
    @objc func nextDisplay() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let current = screens.firstIndex { $0.frame.contains(NSPoint(x: engine.position.x, y: engine.position.y)) } ?? 0
        let frame = screens[(current + 1) % screens.count].visibleFrame
        engine.relocate(Point(frame.midX, frame.minY + 100)); scheduleTimer(1.0 / 30)
    }
    @objc func quit() { NSApp.terminate(nil) }
    func refreshTrust() {
        let now = WindowMover.trusted
        if accessibilityTrusted != now { accessibilityTrusted = now }
    }
    /// Turn on pushing, ask macOS for Accessibility, open the right pane, and watch for the switch.
    func setUpWindowPushing() {
        preferences.pushes = true
        savePreferences()
        refreshTrust()
        guard !accessibilityTrusted else {
            pushSetupNote = "All set. Your pet can push windows that get in its way."
            return
        }
        WindowMover.requestTrust()
        WindowMover.openSettings()
        pushSetupNote = "In System Settings, switch on Perch. This updates by itself."
        trustDeadline = ProcessInfo.processInfo.systemUptime + 180
        trustTimer?.invalidate()
        trustTimer = Timer(timeInterval: 1, target: self, selector: #selector(watchTrust), userInfo: nil, repeats: true)
        RunLoop.main.add(trustTimer!, forMode: .common)
    }
    @objc private func watchTrust() {
        refreshTrust()
        if accessibilityTrusted {
            trustTimer?.invalidate(); trustTimer = nil
            pushSetupNote = "All set. Your pet can push windows that get in its way. Try Test it."
            showSettings()
        } else if ProcessInfo.processInfo.systemUptime > trustDeadline {
            trustTimer?.invalidate(); trustTimer = nil
            pushSetupNote = "Still waiting for Accessibility. If Perch is already switched on, switch it off and on again."
        }
    }
    /// For "it's switched on but Perch still says no": macOS kept a record for an older build of Perch.
    /// Clears Perch's own Accessibility record only, then asks again.
    func resetWindowPushingPermission() {
        let reset = Process()
        reset.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        reset.arguments = ["reset", "Accessibility", Bundle.main.bundleIdentifier ?? "com.perch.desktop"]
        do { try reset.run(); reset.waitUntilExit() } catch {
            pushSetupNote = "Couldn't reset automatically. In System Settings, select Perch, click –, then click Set up again."
            return
        }
        refreshTrust()
        setUpWindowPushing()
        pushSetupNote = "Perch's old permission was cleared. Switch Perch on again in System Settings."
    }
    func savePreferences() {
        guard !captureMode else { return }
        do {
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(preferences).write(to: dataDirectory.appendingPathComponent("preferences.json"), options: .atomic)
        } catch { self.error = "Could not save settings: \(error.localizedDescription)." }
    }
    /// Opens a small Perch window and slides it, proving the permission works without touching other apps.
    func testWindowPush() {
        refreshTrust()
        guard accessibilityTrusted, let screen = NSScreen.main ?? NSScreen.screens.first, let primary = NSScreen.screens.first else {
            pushSetupNote = "Accessibility isn't on for Perch yet, so the test can't run."
            return
        }
        testWindow?.close()
        let label = NSTextField(labelWithString: "Watch me scoot →")
        label.font = .systemFont(ofSize: 15, weight: .semibold); label.alignment = .center
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 260, height: 90),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Perch push test"; window.isReleasedWhenClosed = false
        label.frame = NSRect(x: 0, y: 30, width: 260, height: 24); window.contentView?.addSubview(label)
        let visible = screen.visibleFrame
        var origin = NSPoint(x: visible.minX + 60, y: visible.minY + 60)
        if NSRect(origin: origin, size: window.frame.size).insetBy(dx: -40, dy: -40).contains(NSEvent.mouseLocation) {
            origin.y = visible.midY
        }
        window.setFrameOrigin(origin)
        window.orderFrontRegardless()
        testWindow = window
        pushSetupNote = "Testing…"
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            let before = window.frame.minX
            let frame = CGRect(x: window.frame.minX, y: primary.frame.maxY - window.frame.maxY,
                               width: window.frame.width, height: window.frame.height)
            let started = windowMover.slide(pid: getpid(), frame: frame, by: 90, primaryTop: primary.frame.maxY)
            try? await Task.sleep(for: .milliseconds(1300))
            let moved = window.frame.minX - before
            pushSetupNote = started && moved > 60
                ? "It works. Perch moved its test window \(Int(moved)) points."
                : "The test window didn't move. Keep the pointer still during the test, or switch Perch off and on in Accessibility."
            try? await Task.sleep(for: .milliseconds(1200))
            window.close()
            if testWindow === window { testWindow = nil }
        }
    }
    @objc func sleepSystem() {
        windowMover.cancel()
        locked = true; cancelDrag()
        stopPointerMonitoring()
        for (window, view) in overlays { window.orderOut(nil); view.isPaused = true }
        timer?.invalidate(); timer = nil
    }
    @objc func wakeSystem() {
        locked = false; tracker.poll(); startPointerMonitoring(); scheduleTimer(1.0 / 30)
    }
    @objc func rebuildOverlays() {
        for (window, _) in overlays { window.close() }
        overlays = []
        tracker.poll()
        let screens = NSScreen.screens
        homeDisplays = screens.enumerated().compactMap { index, screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
            return HomeDisplayChoice(id: CFUUIDCreateString(nil, uuid) as String, index: index, name: screen.localizedName)
        }
        for screen in screens {
            let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.acceptsMouseMovedEvents = true
            let view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.controller = self; view.allowsTransparency = true; view.preferredFramesPerSecond = 30
            let scene = PetScene(size: screen.frame.size, rig: rig)
            view.petScene = scene; view.presentScene(scene)
            let canvas = NSView(frame: view.frame)
            view.desktopHome.isHidden = true
            view.desktopHome.bowl.target = self; view.desktopHome.bowl.action = #selector(feed)
            canvas.addSubview(view.desktopHome)
            canvas.addSubview(view); panel.contentView = canvas
            panel.orderFrontRegardless(); overlays.append((panel, view))
        }
        if !tracker.screens.contains(where: { $0.contains(engine.position) }), let safe = tracker.visible.first {
            engine.relocate(Point((safe.minX + safe.maxX) / 2, safe.minY + 100))
        }
        render()
    }
    var homeLocation: (index: Int, home: DesktopHome)? {
        let index = homeDisplays.first { $0.id == preferences.homeDisplayID }?.index ?? 0
        guard tracker.screens.indices.contains(index), !tracker.fullScreenDisplays.contains(index),
              let floor = tracker.surfaces.first(where: { $0.id == "floor-\(index)" }) else { return nil }
        return (index, DesktopHome(screen: tracker.screens[index], floor: floor, corner: preferences.homeCorner ?? .left,
                                   scale: rig.pixelScale))
    }
    func scheduleTimer(_ interval: Double) {
        if timer != nil && abs(tickInterval - interval) < 0.001 { return }
        timer?.invalidate(); tickInterval = interval; lastTick = ProcessInfo.processInfo.systemUptime
        timer = Timer(timeInterval: interval, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }
    @objc func tick() {
        guard !locked else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let dt = max(0, now - lastTick); lastTick = now
        let pollRate = engine.state == .sleep ? 0.5 : engine.state == .ride || engine.cling != nil || engine.cursorPlay != nil ? 1.0 / 30 : 0.1
        var motionDT = pollRate
        if now - lastPoll >= pollRate { motionDT = now - lastPoll; tracker.poll(); lastPoll = now }
        if tracker.unavailable {
            status = "Window bounds are currently unavailable. Your pet can still use the floor. No additional permission is requested."
        }
        let rhythm = Rhythm(hour: Calendar.current.component(.hour, from: Date()),
            idleSeconds: aggregateIdleSeconds(),
            calm: preferences.calm || activePack.temperament == .calm,
            quietStart: preferences.quietStart, quietEnd: preferences.quietEnd, quietEnabled: preferences.quietEnabled)
        let hadFood = engine.care.foodInBowl
        // The climb sprite's paws sit this far above its paw line, so hanging keeps them on the ledge.
        engine.hangDepth = Double(PixelSprites.side - PixelSprites.climbLedgeRow - 1) * rig.pixelScale
        if now - trustChecked > 5 { refreshTrust(); trustChecked = now }
        let lively = !rhythm.calm && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        engine.agile = activePack.species.climbsWindows
        let cursorPlay = preferences.playsWithCursor && lively && engine.agile
        engine.mischief = Mischief(play: lively, chew: preferences.chews && lively, push: preferences.pushes && accessibilityTrusted && lively,
                                   cursor: cursorPlay)
        engine.bodyHalfWidth = Double(PixelSprites.side) / 2 * rig.pixelScale
        engine.muzzleReach = 14 * rig.pixelScale
        // Cursor play reads only where the pointer is right now, and only when it's switched on.
        // With the bamboo on, the panda goes for the stalk's bottom end rather than the arrow's tip.
        engine.bambooPointer = cursorPlay && preferences.showsBamboo
        let pointer = NSEvent.mouseLocation, tip = Point(pointer.x, pointer.y)
        let target = engine.bambooPointer ? Bamboo.end(tip: tip, remaining: engine.bamboo, scale: rig.pixelScale) : tip
        engine.tick(dt: dt, surfaces: tracker.surfaces, screens: tracker.screens, rhythm: rhythm, surfaceDT: motionDT,
                    home: homeLocation?.home, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                    windows: tracker.windows, cursor: cursorPlay && !locked ? target : nil)
        for event in engine.takeEvents() { handle(event) }
        if !preferences.chews && !biteMarks.isEmpty { biteMarks.removeAll() }
        let stale = Date().addingTimeInterval(-20 * 60)
        if biteMarks.contains(where: { $0.made < stale }) { biteMarks.removeAll { $0.made < stale } }
        if !preferences.pushes { windowMover.cancel() }
        if hadFood != engine.care.foodInBowl { saveCareIfNeeded() }
        render()
        // Dangling from the pointer runs at the display's pace so it keeps up with every move.
        scheduleTimer(engine.holdingCursor ? 1.0 / 60 : engine.state == .sleep && engine.ball?.moving != true ? 0.25 : 1.0 / 30)
    }
    func handle(_ event: PetEvent) {
        switch event {
        case .bite(let window, let offset):
            guard preferences.chews else { return }
            biteMarks.append(BiteMark(window: window, offset: offset, made: Date()))
            let cutoff = Date().addingTimeInterval(-20 * 60)
            var perWindow: [UInt32: Int] = [:]
            // Newest first: keep three per window, ten overall, nothing older than twenty minutes.
            biteMarks = Array(biteMarks.reversed().filter { mark in
                perWindow[mark.window, default: 0] += 1
                return mark.made >= cutoff && perWindow[mark.window]! <= 3
            }.prefix(10).reversed())
        case .push(let window, let dx):
            nudge(window: window, by: dx)
        }
    }
    /// Asks Accessibility to slide a window that's in the pet's way, but only as a background nudge.
    @discardableResult
    func nudge(window id: UInt32, by dx: Double) -> Bool {
        guard preferences.pushes, WindowMover.trusted, aggregateIdleSeconds() >= 1.5,
              let window = tracker.windows.first(where: { $0.id == id }), window.pid > 0, window.pid != getpid(),
              !window.bounds.ns.contains(NSEvent.mouseLocation),
              let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(window.bounds.ns) }),
              let primary = NSScreen.screens.first else { return false }
        return slide(window, by: dx, within: screen.visibleFrame, primaryTop: primary.frame.maxY)
    }
    func slide(_ window: DesktopWindow, by dx: Double, within visible: NSRect, primaryTop: Double) -> Bool {
        let room = dx > 0 ? visible.maxX - window.bounds.maxX : visible.minX - window.bounds.minX
        let move = dx > 0 ? min(dx, max(0, room)) : max(dx, min(0, room))
        guard abs(move) >= 4 else { return false }
        let frame = CGRect(x: window.bounds.x, y: primaryTop - window.bounds.maxY,
                           width: window.bounds.width, height: window.bounds.height)
        return windowMover.slide(pid: window.pid, frame: frame, by: move, primaryTop: primaryTop)
    }
    func aggregateIdleSeconds() -> Double {
        // kCGAnyInputEventType provides aggregate idle time without observing input content.
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
    }
    /// The bamboo is on the pointer whenever the red panda would play with it and Perch isn't tucked away.
    var showsBamboo: Bool { engine.bambooPointer && !locked && !engine.bed && engine.bamboo > 0 }
    func render(mouseOverride: NSPoint? = nil) {
        let mouse = mouseOverride ?? NSEvent.mouseLocation
        let scale = rig.pixelScale, size = Double(PixelSprites.side) * scale
        let home = homeLocation
        var lift = 0.0
        if let place = home?.home, engine.support?.id == place.floor.id, place.onRug(engine.position.x) {
            lift = (engine.homeActivity == .napping ? DesktopHome.cushionTop : DesktopHome.rugTop) * scale
        }
        var renderedY = engine.position.y + lift - (engine.support?.kind == .menu ? size : 0)
        var renderedX = engine.position.x
        // Draped over a window edge, its belly rests on the edge and its legs hang in front of the window.
        if engine.trickPose == .drape { renderedY -= Double(PixelSprites.side - 1 - PixelSprites.drapeLedgeRow) * scale }
        // On a window's side the sprite is turned a quarter: its paws grip the edge and its body hangs outside it.
        var rotation = 0.0, flip = engine.direction
        var petBounds = Rect(engine.position.x - size / 2, renderedY, size, size)
        if engine.holdingCursor {
            // Teeth on the pointer's tip: swing about that grip rather than about the paw line.
            let reach = (Double(PixelSprites.side - PixelSprites.hangGripRow) - 0.5) * scale
            rotation = engine.hangSwing
            renderedX = engine.position.x + reach * sin(rotation)
            renderedY = engine.position.y - reach * cos(rotation)
            petBounds = Rect(engine.position.x - size / 2, engine.position.y - reach, size, size)
        } else if let grip = engine.cling, grip.side != .front {
            let up = grip.heading.y >= 0
            if grip.side == .left {
                rotation = .pi / 2; flip = up ? 1 : -1
                petBounds = Rect(engine.position.x - size, renderedY - size / 2, size, size)
            } else {
                rotation = -.pi / 2; flip = up ? -1 : 1
                petBounds = Rect(engine.position.x, renderedY - size / 2, size, size)
            }
        }
        let occluded = Surfaces.occluded(pet: petBounds, target: engine.support?.windowID ?? engine.cling?.window,
                                         windows: tracker.windows)
        var ballRect: Rect?
        if let ball = engine.ball, !locked, !engine.bed {
            let side = 8 * scale, rect = Rect(ball.position.x - side / 2, ball.position.y, side, side)
            if !Surfaces.occluded(pet: rect, target: ball.support?.windowID, windows: tracker.windows) { ballRect = rect }
        }
        // A nibble shows only where its window's top edge is uncovered.
        let biteRects: [Rect] = locked || engine.bed ? [] : biteMarks.compactMap { mark in
            guard let window = tracker.windows.first(where: { $0.id == mark.window }),
                  mark.offset >= 0, mark.offset <= window.bounds.width else { return nil }
            let width = 11 * scale, height = 5 * scale
            let rect = Rect(window.bounds.x + mark.offset - width / 2, window.bounds.maxY - height, width, height)
            return Surfaces.occluded(pet: rect, target: mark.window, windows: tracker.windows) ? nil : rect
        }
        for (index, pair) in overlays.enumerated() {
            let (panel, view) = pair
            let scene = view.petScene!
            // Snap to the display's device pixels so nearest-neighbor art never shimmers.
            let backing = panel.backingScaleFactor
            let local = CGPoint(x: ((renderedX - panel.frame.minX) * backing).rounded() / backing,
                                y: ((renderedY - panel.frame.minY) * backing).rounded() / backing)
            let here = panel.frame.intersects(NSRect(x: petBounds.x, y: petBounds.y, width: petBounds.width, height: petBounds.height))
            let hidden = locked || engine.bed || occluded || tracker.fullScreenDisplays.contains(index) || !here
            let showHome = !locked && !engine.bed && home?.index == index
            if view.desktopHome.isHidden == showHome { view.desktopHome.isHidden = !showHome }
            view.desktopHome.pixelScale = scale
            if showHome, let origin = home?.home.origin {
                let point = NSPoint(x: origin.x - panel.frame.minX, y: origin.y - panel.frame.minY)
                if view.desktopHome.frame.origin != point { view.desktopHome.setFrameOrigin(point) }
                view.desktopHome.bowl.filled = engine.care.foodInBowl || engine.homeActivity == .eating
            }
            let area = Rect(panel.frame), fullScreen = tracker.fullScreenDisplays.contains(index)
            let ballHere = !fullScreen && (ballRect.map { $0.intersects(area) } ?? false)
            let bitesHere = fullScreen ? [] : biteRects.filter { $0.intersects(area) }
            placeBites(bitesHere, in: view, panel: panel)
            if view.ball.superview == nil { view.superview?.addSubview(view.ball, positioned: .above, relativeTo: view) }
            view.ball.apple = activePack.species == .redPanda
            if view.ball.isHidden == ballHere { view.ball.isHidden = !ballHere }
            if let ballRect, let ball = engine.ball, ballHere {
                let frame = NSRect(x: ((ballRect.x - panel.frame.minX) * backing).rounded() / backing,
                                   y: ((ballRect.y - panel.frame.minY) * backing).rounded() / backing,
                                   width: ballRect.width, height: ballRect.height)
                if view.ball.frame != frame { view.ball.frame = frame }
                view.ball.frameIndex = Int(abs(ball.position.x) / (2 * scale)) % 2
            }
            let bambooHere = showsBamboo && !fullScreen && panel.frame.contains(mouse)
            let needed = !hidden || showHome || ballHere || !bitesHere.isEmpty || bambooHere
            if !needed { panel.orderOut(nil) } else if !panel.isVisible { panel.orderFrontRegardless() }
            if view.isHidden != hidden { view.isHidden = hidden }
            scene.sprite.isHidden = hidden
            scene.special = engine.homeActivity == .eating ? .dine : engine.trickPose
            scene.playbackRate = engine.running ? 2 : 1
            scene.selected = engine.action
            scene.still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            scene.sprite.position = local; scene.sprite.setScale(scale)
            scene.sprite.xScale = scale * flip
            if scene.sprite.zRotation != rotation { scene.sprite.zRotation = rotation }
            scene.refresh()
            view.isPaused = hidden || engine.state == .sleep
            scene.isPaused = view.isPaused
        }
        refreshPointerRouting(at: mouse)
    }
    private func placeBites(_ rects: [Rect], in view: OverlayView, panel: NSPanel) {
        guard let canvas = view.superview else { return }
        while view.biteViews.count < rects.count {
            let mark = BiteMarkView(frame: .zero)
            canvas.addSubview(mark, positioned: .below, relativeTo: view)
            view.biteViews.append(mark)
        }
        for (index, mark) in view.biteViews.enumerated() {
            guard index < rects.count else { if !mark.isHidden { mark.isHidden = true }; continue }
            let rect = rects[index]
            let frame = NSRect(x: rect.x - panel.frame.minX, y: rect.y - panel.frame.minY, width: rect.width, height: rect.height)
            if mark.frame != frame { mark.frame = frame }
            if mark.isHidden { mark.isHidden = false }
        }
    }
    /// Keeps the bamboo stalk on the pointer's tip, in front of the pet so it's held up to the panda's mouth.
    /// It never takes clicks; only the pointer's current position is used.
    func placeBamboo(at mouse: NSPoint) {
        let scale = rig.pixelScale
        let length = Bamboo.pixels(remaining: engine.bamboo)
        let rect = Bamboo.frame(tip: Point(mouse.x, mouse.y), scale: scale)
        for (index, pair) in overlays.enumerated() {
            let (panel, view) = pair
            let bamboo = view.bamboo
            if bamboo.superview == nil, let canvas = view.superview { canvas.addSubview(bamboo, positioned: .above, relativeTo: view) }
            let here = showsBamboo && panel.frame.contains(mouse) && !tracker.fullScreenDisplays.contains(index)
            if bamboo.isHidden == here { bamboo.isHidden = !here }
            guard here else { continue }
            let backing = panel.backingScaleFactor
            let frame = NSRect(x: ((rect.x - panel.frame.minX) * backing).rounded() / backing,
                               y: ((rect.y - panel.frame.minY) * backing).rounded() / backing,
                               width: rect.width, height: rect.height)
            if bamboo.frame != frame { bamboo.frame = frame }
            bamboo.length = length
        }
    }
    @discardableResult
    func startPointerMonitoring(currentLocation: @escaping () -> NSPoint = { NSEvent.mouseLocation }) -> Bool {
        if mouseMoveMonitor?.isActive == true { return true }
        let monitor = MouseMoveMonitor(currentLocation: currentLocation) { [weak self] point in
            self?.refreshPointerRouting(at: point)
        }
        mouseMoveMonitor = monitor
        guard monitor.start() else {
            error = "Mouse movement monitoring is unavailable. Alpha routing still uses the timer fallback."
            return false
        }
        return true
    }
    func stopPointerMonitoring() {
        mouseMoveMonitor?.stop()
        mouseMoveMonitor = nil
    }
    func refreshPointerRouting(at mouse: NSPoint) {
        // Hanging on the pointer, the pet must never swallow the clicks meant for whatever is underneath.
        let riding = engine.holdingCursor
        placeBamboo(at: mouse)
        for (panel, view) in overlays {
            guard let scene = view.petScene else { continue }
            let eligible = !locked && panel.isVisible
            let local = CGPoint(x: mouse.x - panel.frame.minX, y: mouse.y - panel.frame.minY)
            let hover = eligible && !riding && scene.alphaHit(local)
            if scene.hover != hover { scene.hover = hover; scene.refresh() }
            let hit = eligible && (!riding && scene.alphaHit(local) || view.desktopHome.bowlHit(local, from: view))
            panel.ignoresMouseEvents = !(hit || eligible && dragOriginal != nil && panel.isKeyWindow)
        }
    }
    func beginDrag() {
        dragOriginal = engine
        let p = NSEvent.mouseLocation
        dragOffset = Point(engine.position.x - p.x, engine.position.y - p.y)
        engine.hold(at: engine.position); scheduleTimer(1.0 / 30); render()
    }
    func drag(at point: NSPoint) {
        engine.drag(to: Point(point.x + dragOffset.x, point.y + dragOffset.y)); render()
    }
    func endDrag(clicked: Bool) {
        if clicked, let original = dragOriginal { engine = original; engine.react(.pet) }
        else { engine.release() }
        dragOriginal = nil; render()
    }
    func cancelDrag() {
        if let original = dragOriginal { engine = original }
        dragOriginal = nil; render()
    }
}
