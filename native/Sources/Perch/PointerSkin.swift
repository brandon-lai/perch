import AppKit
import PerchCore

/// WindowServer's cursor registry, which cursor customizers use to change the system pointer. It's private, so
/// every symbol is looked up at run time; if any is missing, Perch draws the bamboo beside the arrow instead.
struct CursorAPI: @unchecked Sendable {
    typealias Connection = @convention(c) () -> Int32
    typealias Copy = @convention(c) (Int32, UnsafePointer<CChar>, UnsafeMutablePointer<CGSize>, UnsafeMutablePointer<CGPoint>,
                                     UnsafeMutablePointer<UInt>, UnsafeMutablePointer<CGFloat>,
                                     UnsafeMutablePointer<Unmanaged<CFArray>?>) -> Int32
    typealias Register = @convention(c) (Int32, UnsafePointer<CChar>, Bool, Bool, CGSize, CGPoint, UInt, CGFloat, CFArray,
                                         UnsafeMutablePointer<Int32>) -> Int32
    typealias Remove = @convention(c) (Int32, UnsafePointer<CChar>, Bool) -> Int32
    typealias Show = @convention(c) (Int32, Int32) -> Int32
    typealias Property = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
    typealias GlobalSize = @convention(c) (Int32, UnsafeMutablePointer<Int32>) -> Int32
    typealias GlobalData = @convention(c) (Int32, UnsafeMutablePointer<UInt8>, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>,
                                           UnsafeMutablePointer<CGRect>, UnsafeMutablePointer<CGPoint>, UnsafeMutablePointer<Int32>,
                                           UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
    let connection: Int32
    let copy: Copy, register: Register, remove: Remove, show: Show, property: Property
    let globalSize: GlobalSize, globalData: GlobalData

    static let shared: CursorAPI? = {
        let handle = dlopen(nil, RTLD_NOW)
        func symbol<T>(_ name: String, _: T.Type) -> T? { dlsym(handle, name).map { unsafeBitCast($0, to: T.self) } }
        guard let connect = symbol("CGSMainConnectionID", Connection.self),
              let copy = symbol("CGSCopyRegisteredCursorImages", Copy.self),
              let register = symbol("CGSRegisterCursorWithImages", Register.self),
              let remove = symbol("CGSRemoveRegisteredCursor", Remove.self),
              let show = symbol("CoreCursorSet", Show.self),
              let property = symbol("CGSSetConnectionProperty", Property.self),
              let globalSize = symbol("CGSGetGlobalCursorDataSize", GlobalSize.self),
              let globalData = symbol("CGSGetGlobalCursorData", GlobalData.self) else { return nil }
        return CursorAPI(connection: connect(), copy: copy, register: register, remove: remove, show: show,
                         property: property, globalSize: globalSize, globalData: globalData)
    }()

    struct Cursor {
        var size: CGSize, hotspot: CGPoint, frames: UInt, duration: CGFloat, images: [CGImage]
        /// The first representation's pixels, to tell cursors apart.
        var fingerprint: Data { images.first.flatMap { $0.dataProvider?.data as Data? } ?? Data() }
    }

    func read(_ name: String) -> Cursor? {
        var size = CGSize.zero, hotspot = CGPoint.zero, frames: UInt = 0, duration: CGFloat = 0
        var images: Unmanaged<CFArray>?
        guard copy(connection, name, &size, &hotspot, &frames, &duration, &images) == 0,
              let array = images?.takeRetainedValue() as? [CGImage], !array.isEmpty else { return nil }
        return Cursor(size: size, hotspot: hotspot, frames: frames, duration: duration, images: array)
    }
    @discardableResult
    func write(_ name: String, _ cursor: Cursor) -> Bool {
        var seed: Int32 = 0
        return register(connection, name, true, true, cursor.size, cursor.hotspot, max(1, cursor.frames), cursor.duration,
                        cursor.images as CFArray, &seed) == 0
    }
    /// Drops one registration by name (the flag must be set for it to go; other cursors are untouched).
    func forget(_ name: String) { _ = remove(connection, name, true) }

    /// The size and hotspot of the pointer on screen right now (whichever app set it).
    func displayed() -> (size: CGSize, hotspot: CGPoint)? {
        var bytes: Int32 = 0
        guard globalSize(connection, &bytes) == 0, bytes > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: Int(bytes))
        var rowBytes: Int32 = 0, depth: Int32 = 0, components: Int32 = 0, bits: Int32 = 0
        var rect = CGRect.zero, hotspot = CGPoint.zero
        guard globalData(connection, &buffer, &bytes, &rowBytes, &rect, &hotspot, &depth, &components, &bits) == 0 else { return nil }
        return (rect.size, hotspot)
    }
    /// Lets a background app put the arrow back on screen at once, rather than when an app next sets it.
    func showArrow() {
        _ = property(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        _ = show(connection, 0)
    }
}

/// Turns the system arrow into the red panda's bamboo stalk while it plays, eaten down as it nibbles, and puts
/// the real arrow back when it's done, when Perch quits, sleeps or is tucked away, or (via a small guard
/// process and a check at launch) if Perch ever crashes. Only the arrow changes: text cursors, pointing hands
/// and resize arrows stay as they are. The originals are kept in WindowServer under Perch's own names, so a
/// later Perch can restore them.
@MainActor
final class PointerSkin {
    static let arrows = ["com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS"]
    static let savedPrefix = "app.perch.saved."
    static let artWidth = Bamboo.width
    /// Below this many pixels of stalk the pointer is the normal arrow until it grows back.
    static let shortest = 3

    private let api = CursorAPI.shared
    var available: Bool { api != nil }
    private(set) var shown: (length: Int, scale: Double)?
    private var saved: [String: CursorAPI.Cursor] = [:]
    private var checked = 0.0
    private var guardProcess: Process?

    /// The stalk as a cursor: whole-point size, tip as the hotspot, drawn at 1×, 2×, 5× and 10× like the
    /// system's own arrows so it stays crisp at any pointer size.
    static func cursor(length: Int, scale: Double) -> CursorAPI.Cursor? {
        let art = Bamboo.art(length: length)
        let source = pixelImage(Bamboo.palette.rgba(art), width: art.width, height: art.height)
        let size = CGSize(width: Double(artWidth) * scale, height: Double(art.height) * scale)
        var images: [CGImage] = []
        for factor in [1.0, 2.0, 5.0, 10.0] {
            let w = Int((size.width * factor).rounded()), h = Int((size.height * factor).rounded())
            guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.interpolationQuality = .none
            context.draw(source, in: CGRect(x: 0, y: 0, width: w, height: h))
            guard let image = context.makeImage() else { return nil }
            images.append(image)
        }
        // The stalk's top end is the pointer's tip, as where Perch has always put it.
        let hotspot = CGPoint(x: Bamboo.centerX * scale, y: 1.5 * scale)
        return CursorAPI.Cursor(size: size, hotspot: hotspot, frames: 1, duration: 0, images: images)
    }

    /// A bamboo cursor from any Perch, at any pet size: its size and tip give it away.
    static func isBamboo(_ cursor: CursorAPI.Cursor) -> Bool {
        let scales: [Double] = [1, 1.5, 2]
        return scales.contains { (scale: Double) -> Bool in
            let width = Double(artWidth) * scale, height = Double(Bamboo.height) * scale
            let sized = abs(Double(cursor.size.width) - width) < 0.01 && abs(Double(cursor.size.height) - height) < 0.01
            let tipped = abs(Double(cursor.hotspot.x) - Bamboo.centerX * scale) < 0.6 && abs(Double(cursor.hotspot.y) - 1.5 * scale) < 0.6
            return sized && tipped
        }
    }

    /// Makes the arrow a stalk `length` pixels long. Returns false (leaving the arrow alone) when it can't.
    @discardableResult
    func show(length: Int, scale: Double) -> Bool {
        guard let api, length >= Self.shortest else { hide(); return false }
        let now = ProcessInfo.processInfo.systemUptime
        if let shown, shown.length == length, shown.scale == scale {
            // Now and then, make sure macOS hasn't put its own arrow back (a pointer size change does).
            guard now - checked > 3 else { return true }
            checked = now
            if Self.arrows.allSatisfy({ api.read($0).map(Self.isBamboo) ?? false }) { return true }
            saved.removeAll()
        }
        checked = now
        guard let stalk = Self.cursor(length: length, scale: scale) else { return false }
        // Keep the real arrows first, in memory and in WindowServer for a later Perch.
        for name in Self.arrows where saved[name] == nil {
            guard let current = api.read(name) else { return false }
            if Self.isBamboo(current) {
                guard let kept = api.read(Self.savedPrefix + name) else { return false }
                saved[name] = kept
            } else {
                saved[name] = current
                api.write(Self.savedPrefix + name, current)
            }
        }
        let wasArrow = displayingArrow()
        for name in Self.arrows where !api.write(name, stalk) { shown = (length, scale); hide(); return false }
        guard Self.arrows.allSatisfy({ api.read($0).map(Self.isBamboo) ?? false }) else { shown = (length, scale); hide(); return false }
        shown = (length, scale)
        if wasArrow { api.showArrow() }
        startGuard()
        return true
    }

    /// Puts the real arrow back, unless macOS has already replaced the stalk with its own.
    func hide() {
        guard let api, shown != nil else { return }
        let wasStalk = displayingStalk()
        for name in Self.arrows {
            if let original = saved[name] ?? api.read(Self.savedPrefix + name), api.read(name).map(Self.isBamboo) ?? true {
                api.write(name, original)
            }
            api.forget(Self.savedPrefix + name)
        }
        saved.removeAll(); shown = nil
        if wasStalk { api.showArrow() }
    }

    /// Restores the arrows a Perch that didn't get to tidy up left as bamboo. Run at launch and by the guard.
    static func recover() {
        guard let api = CursorAPI.shared else { return }
        let showing = api.displayed().map { isBamboo(CursorAPI.Cursor(size: $0.size, hotspot: $0.hotspot, frames: 1, duration: 0, images: [])) } ?? false
        for name in arrows {
            guard let original = api.read(savedPrefix + name) else { continue }
            if api.read(name).map(isBamboo) ?? true { api.write(name, original) }
            api.forget(savedPrefix + name)
        }
        if showing { api.showArrow() }
    }

    private func displayingArrow() -> Bool {
        guard let api, let shown = api.displayed() else { return false }
        return Self.arrows.contains { name in
            guard let arrow = saved[name] ?? api.read(name) else { return false }
            return arrow.size == shown.size && abs(arrow.hotspot.x - shown.hotspot.x) < 1 && abs(arrow.hotspot.y - shown.hotspot.y) < 1
        } || displayingStalk()
    }
    private func displayingStalk() -> Bool {
        guard let api, let displayed = api.displayed() else { return false }
        return Self.isBamboo(CursorAPI.Cursor(size: displayed.size, hotspot: displayed.hotspot, frames: 1, duration: 0, images: []))
    }

    /// Forgets the stalk without restoring anything, as a crash would. Evidence only.
    func abandon() { saved.removeAll(); shown = nil }

    /// A tiny copy of Perch that waits for this one to exit, however it exits, and puts the arrow back.
    private func startGuard() {
        guard guardProcess?.isRunning != true, let executable = Bundle.main.executableURL else { return }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--pointer-guard", String(getpid())]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        if (try? process.run()) != nil { guardProcess = process }
    }
}

/// `Perch --pointer-guard <pid>`: no windows, no Dock icon; restores the arrow once that Perch has gone.
enum PointerGuard {
    static func run(watching pid: pid_t) -> Never {
        func finish() -> Never { MainActor.assumeIsolated { PointerSkin.recover() }; exit(0) }
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler { finish() }
        source.resume()
        // In case it had already gone before the watch began.
        let poll = DispatchSource.makeTimerSource(queue: .main)
        poll.schedule(deadline: .now(), repeating: 2)
        poll.setEventHandler { if kill(pid, 0) != 0 && errno == ESRCH { finish() } }
        poll.resume()
        withExtendedLifetime((source, poll)) { dispatchMain() }
    }
}
