import AppKit
import ApplicationServices
import PerchCore

/// Nudges another app's window through Accessibility. Only position and size are read; never titles or contents.
@MainActor
final class WindowMover: NSObject {
    static var trusted: Bool { AXIsProcessTrusted() }
    static func requestTrust() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private var timer: Timer?
    private var target: AXUIElement?
    private var start = CGPoint.zero, lastSet = CGPoint.zero
    private var size = CGSize.zero
    private var offset: CGFloat = 0, primaryTop: CGFloat = 0
    private var began = 0.0
    private var step = 0
    private let steps = 27
    private(set) var moves = 0

    /// Slides the window whose top-left-origin frame matches `frame` by `dx` points over about 0.9 s.
    @discardableResult
    func slide(pid: pid_t, frame: CGRect, by dx: CGFloat, primaryTop: CGFloat) -> Bool {
        guard Self.trusted, timer == nil, let window = Self.window(pid: pid, matching: frame) else { return false }
        target = window; start = frame.origin; lastSet = frame.origin; size = frame.size
        offset = dx; step = 0; self.primaryTop = primaryTop; began = ProcessInfo.processInfo.systemUptime
        timer = Timer(timeInterval: 1.0 / 30, target: self, selector: #selector(advance), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
        return true
    }

    @objc private func advance() {
        guard let target else { cancel(); return }
        // Stop the moment the person does anything: input, a held button, the pointer over it, or a move of their own.
        let since = ProcessInfo.processInfo.systemUptime - began
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        let mouse = NSEvent.mouseLocation
        let pointer = CGPoint(x: mouse.x, y: primaryTop - mouse.y)
        let current = Self.value(target, kAXPositionAttribute, CGPoint.zero, .cgPoint)
        if idle < since || NSEvent.pressedMouseButtons != 0 || CGRect(origin: lastSet, size: size).contains(pointer) ||
            current.map({ hypot($0.x - lastSet.x, $0.y - lastSet.y) > 2 }) ?? true {
            cancel(); return
        }
        step += 1
        let t = min(1, Double(step) / Double(steps)), eased = t * t * (3 - 2 * t)
        var point = CGPoint(x: start.x + offset * eased, y: start.y)
        guard let value = AXValueCreate(.cgPoint, &point),
              AXUIElementSetAttributeValue(target, kAXPositionAttribute as CFString, value) == .success else { cancel(); return }
        lastSet = point
        if t >= 1 { cancel(); moves += 1 }
    }

    func cancel() { timer?.invalidate(); timer = nil; target = nil }

    static func window(pid: pid_t, matching frame: CGRect) -> AXUIElement? {
        var list: CFTypeRef?
        let app = AXUIElementCreateApplication(pid)
        // A hung app must not stall the pet: give up on any Accessibility reply after a quarter second.
        AXUIElementSetMessagingTimeout(app, 0.25)
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &list) == .success,
              let windows = list as? [AXUIElement] else { return nil }
        return windows.first { window in
            guard let origin = value(window, kAXPositionAttribute, CGPoint.zero, .cgPoint),
                  let size = value(window, kAXSizeAttribute, CGSize.zero, .cgSize) else { return false }
            return abs(origin.x - frame.minX) < 2 && abs(origin.y - frame.minY) < 2 &&
                abs(size.width - frame.width) < 2 && abs(size.height - frame.height) < 2
        }
    }

    private static func value<T>(_ element: AXUIElement, _ attribute: String, _ empty: T, _ type: AXValueType) -> T? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var result = empty
        return AXValueGetValue(raw as! AXValue, type, &result) ? result : nil
    }
}

/// A temporary nibble drawn in our overlay at another window's top edge. That window is never modified.
struct BiteMark {
    let window: UInt32
    let offset: Double
    let made: Date
}

@MainActor
final class BallView: NSView {
    static let images: [CGImage] = (0..<2).map { frame in
        let art = PixelSprites.ball(frame)
        return pixelImage(PixelSprites.toyPalette.rgba(art), width: art.width, height: art.height)
    }
    static let appleImages: [CGImage] = (0..<2).map { frame in
        let art = PixelSprites.apple(frame)
        return pixelImage(PixelSprites.toyPalette.rgba(art), width: art.width, height: art.height)
    }
    var frameIndex = 0 { didSet { if frameIndex != oldValue { needsDisplay = true } } }
    /// Red pandas play with an apple instead of a ball.
    var apple = false { didSet { if apple != oldValue { needsDisplay = true } } }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = .none
        context.draw((apple ? Self.appleImages : Self.images)[frameIndex % 2], in: bounds)
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class BiteMarkView: NSView {
    static let image: CGImage = {
        let art = PixelSprites.biteMark()
        return pixelImage(PixelSprites.bitePalette.rgba(art), width: art.width, height: art.height)
    }()
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = .none
        context.draw(Self.image, in: bounds)
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
