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
    var dataDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Perch", isDirectory: true)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        captureMode = args.contains("--capture-preview") || args.contains("--capture-settings") ||
            args.contains("--verify-fixture") || args.contains("--verify-home") || args.contains("--verify-pack") ||
            args.contains("--capture-sprites")
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
                activePack = try PetPack.decode(Data(contentsOf: packURL))
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
    }
    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Perch")
        let menu = NSMenu()
        for (name, selector) in [
            ("Wake", #selector(wake)), ("Send to bed  ⌃⌥⌘B", #selector(bed)),
            ("Pet", #selector(pet)), ("Fill food bowl", #selector(feed)), ("Play ball", #selector(play)),
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
    @objc func play() { engine.react(.play); scheduleTimer(1.0 / 30) }
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
    @objc func sleepSystem() {
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
        let pollRate = engine.state == .sleep ? 0.5 : engine.state == .ride ? 1.0 / 30 : 0.1
        var motionDT = pollRate
        if now - lastPoll >= pollRate { motionDT = now - lastPoll; tracker.poll(); lastPoll = now }
        if tracker.unavailable {
            status = "Window bounds are currently unavailable. Your pet can still use the floor. No additional permission is requested."
        }
        let rhythm = Rhythm(hour: Calendar.current.component(.hour, from: Date()),
            idleSeconds: aggregateIdleSeconds(),
            calm: preferences.calm || activePack.temperament == .calm || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            quietStart: preferences.quietStart, quietEnd: preferences.quietEnd, quietEnabled: preferences.quietEnabled)
        let hadFood = engine.care.foodInBowl
        // The climb sprite's paws sit this far above its paw line, so hanging keeps them on the ledge.
        engine.hangDepth = Double(PixelSprites.side - PixelSprites.climbLedgeRow - 1) * rig.pixelScale
        engine.tick(dt: dt, surfaces: tracker.surfaces, screens: tracker.screens, rhythm: rhythm, surfaceDT: motionDT,
                    home: homeLocation?.home, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        if hadFood != engine.care.foodInBowl { saveCareIfNeeded() }
        render()
        scheduleTimer(engine.state == .sleep ? 0.25 : 1.0 / 30)
    }
    func aggregateIdleSeconds() -> Double {
        // kCGAnyInputEventType provides aggregate idle time without observing input content.
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
    }
    func render(mouseOverride: NSPoint? = nil) {
        let mouse = mouseOverride ?? NSEvent.mouseLocation
        let scale = rig.pixelScale, size = Double(PixelSprites.side) * scale
        let home = homeLocation
        var lift = 0.0
        if let place = home?.home, engine.support?.id == place.floor.id, place.onRug(engine.position.x) {
            lift = (engine.homeActivity == .napping ? DesktopHome.cushionTop : DesktopHome.rugTop) * scale
        }
        let renderedY = engine.position.y + lift - (engine.support?.kind == .menu ? size : 0)
        let petBounds = Rect(engine.position.x - size / 2, renderedY, size, size)
        let occluded = Surfaces.occluded(pet: petBounds, target: engine.support?.windowID, windows: tracker.windows)
        for (index, pair) in overlays.enumerated() {
            let (panel, view) = pair
            let scene = view.petScene!
            // Snap to the display's device pixels so nearest-neighbor art never shimmers.
            let backing = panel.backingScaleFactor
            let local = CGPoint(x: ((engine.position.x - panel.frame.minX) * backing).rounded() / backing,
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
            if hidden && !showHome { panel.orderOut(nil) } else if !panel.isVisible { panel.orderFrontRegardless() }
            if view.isHidden != hidden { view.isHidden = hidden }
            scene.sprite.isHidden = hidden
            scene.atDish = engine.homeActivity == .eating
            scene.selected = engine.action
            scene.still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || preferences.calm
            scene.sprite.position = local; scene.sprite.setScale(scale)
            scene.sprite.xScale = scale * engine.direction
            scene.refresh()
            view.isPaused = hidden || engine.state == .sleep
            scene.isPaused = view.isPaused
        }
        refreshPointerRouting(at: mouse)
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
        for (panel, view) in overlays {
            guard let scene = view.petScene else { continue }
            let eligible = !locked && panel.isVisible
            let local = CGPoint(x: mouse.x - panel.frame.minX, y: mouse.y - panel.frame.minY)
            let hover = eligible && scene.alphaHit(local)
            if scene.hover != hover { scene.hover = hover; scene.refresh() }
            let hit = eligible && (scene.alphaHit(local) || view.desktopHome.bowlHit(local, from: view))
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
