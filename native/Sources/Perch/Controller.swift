import AppKit
import SwiftUI
import SpriteKit
import Carbon
import UniformTypeIdentifiers
import PerchCore

struct Preferences: Codable {
    var quietEnabled = true
    var quietStart = 22
    var quietEnd = 7
    /// Read once from older settings to place the tree where the home was.
    var homeDisplayID: String?
    var homeCorner: HomeCorner?
    var treeDisplayID: String?
    var treePosition: Double?
    var treeShown: Bool?
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
    var showsTree: Bool { get { treeShown ?? true } set { treeShown = newValue } }
    /// Which display the tree stands on (nil is the main display), and where along its bottom, 0 to 1.
    var treeDisplay: String? { get { treeDisplayID } set { treeDisplayID = newValue } }
    var treePlace: Double { get { treePosition ?? 0.06 } set { treePosition = newValue } }
    /// Moves the old home's display and corner over to the tree, once, so later choices (including the main
    /// display, stored as nil) stick.
    mutating func adoptLegacyHome() {
        if treeDisplayID == nil, let legacy = homeDisplayID { treeDisplayID = legacy }
        if treePosition == nil, let corner = homeCorner { treePosition = corner == .right ? 0.94 : 0.06 }
        homeDisplayID = nil; homeCorner = nil
    }
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
    let tree = TreeView()
    var biteViews: [BiteMarkView] = []
    let ball = BallView(frame: .zero)
    let bamboo = BambooView(frame: .zero)
    var down = NSPoint.zero
    var dragged = false
    override var acceptsFirstResponder: Bool { true }
    var movingTree = false
    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        guard let controller else { return }
        if petScene.alphaHit(local) {
            down = NSEvent.mouseLocation; dragged = false
            controller.beginDrag()
            window?.makeKey(); window?.makeFirstResponder(self)
        } else if let canvas = superview, tree.treeHit(convert(local, to: canvas), from: canvas) {
            movingTree = true
            controller.beginTreeDrag(at: NSEvent.mouseLocation)
        }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let controller else { return }
        let p = NSEvent.mouseLocation
        if movingTree { controller.dragTree(to: p); return }
        guard controller.dragOriginal != nil else { return }
        dragged = dragged || hypot(p.x - down.x, p.y - down.y) > 3
        controller.drag(at: p)
    }
    override func mouseUp(with event: NSEvent) {
        guard let controller else { return }
        if movingTree { movingTree = false; controller.endTreeDrag(); return }
        guard controller.dragOriginal != nil else { return }
        controller.endDrag(clicked: !dragged, count: event.clickCount)
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
    @Published var draft = PetPack.redPanda()
    @Published var preferences = Preferences()
    @Published var error: String?
    @Published var status = "Name your red panda, then choose Save & wake."
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
    var activePack = PetPack.redPanda()
    var rig = PetRig(pack: PetPack.redPanda())
    var treeDragOffset = 0.0
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
    /// The bamboo as the system arrow itself, where macOS allows it.
    let pointerSkin = PointerSkin()
    /// Registering the stalk failed once: draw it beside the arrow for the rest of the session.
    var pointerSkinFailed = false
    /// Evidence runs leave the real pointer alone unless they're checking the pointer skin itself.
    var pointerSkinAllowed = true
    private var quitSignals: [DispatchSourceSignal] = []
    private var trustChecked = -10.0
    var dataDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Perch", isDirectory: true)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        captureMode = args.contains("--capture-preview") || args.contains("--capture-settings") ||
            args.contains("--verify-fixture") || args.contains("--verify-tree") ||
            args.contains("--capture-sprites") || args.contains("--verify-mischief") ||
            args.contains("--verify-climb") || args.contains("--verify-cursor") || args.contains("--export-site-art") ||
            args.contains("--capture-climb-poses") || args.contains("--verify-pointer")
        NSApp.setActivationPolicy(.accessory)
        if captureMode { pointerSkinAllowed = false; runEvidence(arguments: args); return }
        // A Perch that didn't get to tidy up may have left the arrow as bamboo.
        PointerSkin.recover()
        for signal in [SIGTERM, SIGINT, SIGHUP] {
            Darwin.signal(signal, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signal, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.pointerSkin.hide() }
                exit(0)
            }
            source.resume(); quitSignals.append(source)
        }
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
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        pointerSkin.hide()
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
                // One red panda, one look: only its name is kept from what was saved.
                let saved = try PetPack.decode(Data(contentsOf: packURL))
                activePack = PetPack.redPanda(name: saved.name)
                draft = activePack; rig = PetRig(pack: activePack); committed = true
            } catch { self.error = "Saved pet could not be opened: \(error.localizedDescription). Maple is here instead." }
        }
        let prefsURL = dataDirectory.appendingPathComponent("preferences.json")
        if FileManager.default.fileExists(atPath: prefsURL.path) {
            do {
                preferences = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: prefsURL))
                preferences.adoptLegacyHome()
            }
            catch { self.error = "Saved settings could not be opened: \(error.localizedDescription)." }
        }
    }
    func commit() {
        do {
            let pack = try PetPack.redPanda(name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines)).validated()
            if !captureMode {
                try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
                try pack.encoded().write(to: dataDirectory.appendingPathComponent("pet.perchpack"), options: .atomic)
                try JSONEncoder().encode(preferences).write(to: dataDirectory.appendingPathComponent("preferences.json"), options: .atomic)
            }
            activePack = pack; draft = pack; rig = PetRig(pack: pack); committed = true
            for (_, view) in overlays { view.petScene.rig = rig; view.petScene.refresh() }
            status = "\(pack.name) is ready."
            engine.setBed(false)
        } catch { self.error = error.localizedDescription }
    }
    func deletePet() {
        do {
            for file in ["pet.perchpack", "preferences.json", "care.json"] {
                let url = dataDirectory.appendingPathComponent(file)
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }
            activePack = PetPack.redPanda(); draft = activePack; preferences = Preferences(); rig = PetRig(pack: activePack)
            committed = false; engine.setBed(true)
            for (_, view) in overlays { view.petScene.rig = rig }
            status = "Perch is reset. Name your red panda and choose Save & wake."
        } catch { self.error = "Could not reset Perch: \(error.localizedDescription)." }
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 780),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Perch — your desktop red panda"
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
            ("Wake", #selector(wake)), ("Take a nap", #selector(nap)), ("Tuck away  ⌃⌥⌘B", #selector(bed)),
            ("Pet", #selector(pet)), ("Go to its tree", #selector(goToTree)), ("Play ball", #selector(play)),
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
            error = "The tuck-away shortcut could not register (code \(result)). Tuck away remains available in the menu."
        }
    }
    @objc func wake() { engine.wakeUp(); scheduleTimer(1.0 / 30) }
    /// A nap where it likes, a window's top edge or its tree, until it's woken.
    @objc func nap() {
        if dragOriginal != nil { cancelDrag() }
        engine.takeNap(); scheduleTimer(1.0 / 30)
    }
    @objc func bed() { engine.setBed(true); dragOriginal = nil; pointerSkin.hide(); render() }
    @objc func pet() { engine.react(.pet); scheduleTimer(1.0 / 30) }
    @objc func goToTree() {
        if dragOriginal != nil { cancelDrag() }
        engine.goToTree(); scheduleTimer(1.0 / 30)
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
        pointerSkin.hide()
        windowMover.cancel()
        locked = true; cancelDrag()
        stopPointerMonitoring()
        for (window, view) in overlays { window.orderOut(nil); view.isPaused = true }
        timer?.invalidate(); timer = nil
    }
    @objc func wakeSystem() {
        // The display wakes to the lock screen before the session unlocks: stay paused (and the arrow an arrow)
        // until the unlock notification.
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any],
           (session["CGSSessionScreenIsLocked"] as? Bool) == true { return }
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
            view.tree.isHidden = true
            canvas.addSubview(view.tree)
            canvas.addSubview(view); panel.contentView = canvas
            panel.orderFrontRegardless(); overlays.append((panel, view))
        }
        if !tracker.screens.contains(where: { $0.contains(engine.position) }), let safe = tracker.visible.first {
            engine.relocate(Point((safe.minX + safe.maxX) / 2, safe.minY + 100))
        }
        render()
    }
    var treeLocation: (index: Int, tree: TreeHome)? {
        guard preferences.showsTree else { return nil }
        let index = homeDisplays.first { $0.id == preferences.treeDisplay }?.index ?? 0
        guard tracker.screens.indices.contains(index), !tracker.fullScreenDisplays.contains(index),
              let floor = tracker.surfaces.first(where: { $0.id == "floor-\(index)" }) else { return nil }
        return (index, TreeHome(floor: floor, position: preferences.treePlace, scale: rig.pixelScale))
    }
    func beginTreeDrag(at point: NSPoint) {
        guard let tree = treeLocation?.tree else { return }
        treeDragOffset = point.x - (tree.origin.x + tree.width / 2)
        scheduleTimer(1.0 / 30)
    }
    /// Moves the tree along the bottom of whichever display the pointer is over.
    func dragTree(to point: NSPoint) {
        let index = tracker.screens.firstIndex { $0.contains(Point(point.x, point.y)) } ??
            homeDisplays.first { $0.id == preferences.treeDisplay }?.index ?? 0
        guard let floor = tracker.surfaces.first(where: { $0.id == "floor-\(index)" }) else { return }
        preferences.treeDisplay = homeDisplays.first { $0.index == index }?.id
        preferences.treePlace = TreeHome.position(centeredAt: point.x - treeDragOffset, floor: floor, scale: rig.pixelScale)
        render()
    }
    func endTreeDrag() { savePreferences() }
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
        // Asleep on a window it checks a little more often, so a drag carries it along rather than leaving it behind.
        let pollRate = engine.recentlyCarried ? 1.0 / 30 : engine.state == .sleep ? (engine.support?.kind == .window ? 0.25 : 0.5)
            : engine.state == .ride || engine.cling != nil || engine.cursorPlay != nil ? 1.0 / 30 : 0.1
        var motionDT = pollRate
        if now - lastPoll >= pollRate { motionDT = now - lastPoll; tracker.poll(); lastPoll = now }
        if tracker.unavailable {
            status = "Window bounds are currently unavailable. Your pet can still use the floor. No additional permission is requested."
        }
        let rhythm = Rhythm(hour: Calendar.current.component(.hour, from: Date()),
            idleSeconds: aggregateIdleSeconds(),
            calm: false,
            quietStart: preferences.quietStart, quietEnd: preferences.quietEnd, quietEnabled: preferences.quietEnabled)
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
                    tree: treeLocation?.tree, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                    windows: tracker.windows, cursor: cursorPlay && !locked ? target : nil)
        for event in engine.takeEvents() { handle(event) }
        if !preferences.chews && !biteMarks.isEmpty { biteMarks.removeAll() }
        let stale = Date().addingTimeInterval(-20 * 60)
        if biteMarks.contains(where: { $0.made < stale }) { biteMarks.removeAll { $0.made < stale } }
        if !preferences.pushes { windowMover.cancel() }
        render()
        // Dangling from the pointer runs at the display's pace so it keeps up with every move.
        scheduleTimer(engine.holdingCursor ? 1.0 / 60
            : engine.state == .sleep && engine.ball?.moving != true && !engine.recentlyCarried ? 0.25 : 1.0 / 30)
    }
    func handle(_ event: PetEvent) {
        switch event {
        case .bite(let window, let edge, let offset):
            guard preferences.chews else { return }
            biteMarks.append(BiteMark(window: window, edge: edge, offset: offset, made: Date()))
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
    /// The arrow itself can be the stalk: macOS allows it, it hasn't failed, and this isn't an evidence run.
    var skinsPointer: Bool { pointerSkinAllowed && pointerSkin.available && !pointerSkinFailed }
    func render(mouseOverride: NSPoint? = nil) {
        let mouse = mouseOverride ?? NSEvent.mouseLocation
        let scale = rig.pixelScale, size = Double(PixelSprites.side) * scale
        let home = treeLocation
        var renderedY = engine.position.y - (engine.support?.kind == .menu ? size : 0)
        var renderedX = engine.position.x
        // Draped over a window edge, its belly rests on the edge and its legs hang in front of the window.
        if PixelSprites.drapes(engine.trickPose) { renderedY -= Double(PixelSprites.side - 1 - PixelSprites.drapeLedgeRow) * scale }
        var rotation = 0.0, flip = engine.direction
        // Climbing poses are drawn upright about the torso (or, side on to a window, about the edge it grips),
        // in larger frames whose stride frame comes from how far it has climbed.
        let climbing = engine.trickPose.map { PixelSprites.climbHead($0) != nil } ?? false
        let frameSide = climbing ? PixelSprites.climbSide : PixelSprites.side
        var petBounds = Rect(engine.position.x - size / 2, renderedY, size, size)
        if engine.holdingCursor {
            // Teeth on the pointer's tip: swing about that grip rather than about the paw line.
            let reach = (Double(PixelSprites.side - PixelSprites.hangGripRow) - 0.5) * scale
            rotation = engine.hangSwing
            renderedX = engine.position.x + reach * sin(rotation)
            renderedY = engine.position.y - reach * cos(rotation)
            petBounds = Rect(engine.position.x - size / 2, engine.position.y - reach, size, size)
        } else if climbing {
            let half = Double(frameSide) / 2 * scale
            renderedX = engine.position.x; renderedY = engine.position.y
            petBounds = Rect(engine.position.x - half, engine.position.y - half, half * 2, half * 2)
        }
        let occluded = Surfaces.occluded(pet: petBounds, target: engine.support?.windowID ?? engine.cling?.window,
                                         windows: tracker.windows)
        var ballRect: Rect?
        if let ball = engine.ball, !locked, !engine.bed {
            let side = 8 * scale, rect = Rect(ball.position.x - side / 2, ball.position.y, side, side)
            if !Surfaces.occluded(pet: rect, target: ball.support?.windowID, windows: tracker.windows) { ballRect = rect }
        }
        // A nibble shows only where its window's top edge is uncovered.
        let biteRects: [(Rect, BiteEdge)] = locked || engine.bed ? [] : biteMarks.compactMap { mark in
            guard let window = tracker.windows.first(where: { $0.id == mark.window }) else { return nil }
            let b = window.bounds, long = 2 * PixelSprites.biteMarkHalfLength * scale, short = 5 * scale
            let rect: Rect
            switch mark.edge {
            case .top:
                guard mark.offset >= 0, mark.offset <= b.width else { return nil }
                rect = Rect(b.x + mark.offset - long / 2, b.maxY - short, long, short)
            case .left, .right:
                guard mark.offset >= long / 2, mark.offset <= b.height - long / 2 else { return nil }
                rect = Rect(mark.edge == .left ? b.minX : b.maxX - short, b.y + mark.offset - long / 2, short, long)
            }
            return Surfaces.occluded(pet: rect, target: mark.window, windows: tracker.windows) ? nil : (rect, mark.edge)
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
            if view.tree.isHidden == showHome { view.tree.isHidden = !showHome }
            view.tree.pixelScale = scale
            if showHome, let origin = home?.tree.origin {
                let point = NSPoint(x: ((origin.x - panel.frame.minX) * backing).rounded() / backing,
                                    y: ((origin.y - panel.frame.minY) * backing).rounded() / backing)
                if view.tree.frame.origin != point { view.tree.setFrameOrigin(point) }
            }
            let area = Rect(panel.frame), fullScreen = tracker.fullScreenDisplays.contains(index)
            let ballHere = !fullScreen && (ballRect.map { $0.intersects(area) } ?? false)
            let bitesHere = fullScreen ? [] : biteRects.filter { $0.0.intersects(area) }
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
            let bambooHere = showsBamboo && !skinsPointer && !fullScreen && panel.frame.contains(mouse)
            let needed = !hidden || showHome || ballHere || !bitesHere.isEmpty || bambooHere
            if !needed { panel.orderOut(nil) } else if !panel.isVisible { panel.orderFrontRegardless() }
            if view.isHidden != hidden { view.isHidden = hidden }
            scene.sprite.isHidden = hidden
            scene.special = engine.trickPose
            scene.strideFrame = climbing ? engine.strideFrame : nil
            scene.playbackRate = engine.running ? 2 : 1
            scene.selected = engine.action
            scene.still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            let unit = scale * Double(frameSide) / Double(PixelSprites.side)
            scene.sprite.position = local; scene.sprite.setScale(unit)
            scene.sprite.xScale = unit * flip
            if scene.sprite.zRotation != rotation { scene.sprite.zRotation = rotation }
            // Z's rise from its head while it sleeps, or a heart when it's petted in its sleep.
            scene.bubbleKind = hidden ? nil : engine.bubble
            scene.bubbleRightward = flip > 0
            if let pose = engine.trickPose, PixelSprites.asleep(pose) {
                let head = PixelSprites.sleepingHead(pose)
                scene.bubble.position = CGPoint(
                    x: ((local.x + flip * Double(head.x - PixelSprites.side / 2) * scale) * backing).rounded() / backing,
                    y: ((local.y + Double(PixelSprites.side - head.y) * scale) * backing).rounded() / backing)
                scene.bubble.setScale(scale)
            } else { scene.bubbleKind = nil }
            scene.refresh()
            view.isPaused = hidden
            scene.isPaused = view.isPaused
            // Asleep it only breathes and puffs z's: a few frames a second is plenty.
            let fps = engine.state == .sleep && !engine.recentlyCarried ? 4 : 30
            if view.preferredFramesPerSecond != fps { view.preferredFramesPerSecond = fps }
        }
        refreshPointerRouting(at: mouse)
    }
    private func placeBites(_ rects: [(Rect, BiteEdge)], in view: OverlayView, panel: NSPanel) {
        guard let canvas = view.superview else { return }
        while view.biteViews.count < rects.count {
            let mark = BiteMarkView(frame: .zero)
            canvas.addSubview(mark, positioned: .below, relativeTo: view)
            view.biteViews.append(mark)
        }
        for (index, mark) in view.biteViews.enumerated() {
            guard index < rects.count else { if !mark.isHidden { mark.isHidden = true }; continue }
            let (rect, edge) = rects[index]
            let frame = NSRect(x: rect.x - panel.frame.minX, y: rect.y - panel.frame.minY, width: rect.width, height: rect.height)
            if mark.frame != frame { mark.frame = frame }
            mark.edge = edge
            if mark.isHidden { mark.isHidden = false }
        }
    }
    /// Keeps the bamboo stalk on the pointer's tip, in front of the pet so it's held up to the panda's mouth.
    /// It never takes clicks; only the pointer's current position is used.
    func placeBamboo(at mouse: NSPoint) {
        let scale = rig.pixelScale
        let length = Bamboo.pixels(remaining: engine.bamboo)
        let rect = Bamboo.frame(tip: Point(mouse.x, mouse.y), scale: scale)
        // Over a full-screen app the pointer is the normal arrow, as the pet isn't there either.
        let pointerDisplay = overlays.firstIndex { $0.0.frame.contains(mouse) }
        let overFullScreen = pointerDisplay.map { tracker.fullScreenDisplays.contains($0) } ?? false
        if skinsPointer {
            if showsBamboo && !overFullScreen {
                if !pointerSkin.show(length: length, scale: scale) && length >= PointerSkin.shortest { pointerSkinFailed = true }
            } else { pointerSkin.hide() }
        }
        for (index, pair) in overlays.enumerated() {
            let (panel, view) = pair
            let bamboo = view.bamboo
            if bamboo.superview == nil, let canvas = view.superview { canvas.addSubview(bamboo, positioned: .above, relativeTo: view) }
            let here = showsBamboo && !skinsPointer && panel.frame.contains(mouse) && !tracker.fullScreenDisplays.contains(index)
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
            let hit = eligible && (!riding && scene.alphaHit(local) || view.tree.treeHit(local, from: view))
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
    /// A click pets it (asleep, it snuggles in); a double-click wakes it.
    func endDrag(clicked: Bool, count: Int = 1) {
        if clicked, let original = dragOriginal {
            engine = original
            if count >= 2 && engine.state == .sleep { engine.wakeUp() } else { engine.react(.pet) }
        }
        else { engine.release() }
        dragOriginal = nil; render()
    }
    func cancelDrag() {
        if let original = dragOriginal { engine = original }
        dragOriginal = nil; render()
    }
}
