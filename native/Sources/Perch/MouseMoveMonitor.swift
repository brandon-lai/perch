import AppKit

@MainActor
final class MouseMoveMonitor {
    static let eventMask: NSEvent.EventTypeMask = .mouseMoved
    private var globalToken: Any?
    private var localToken: Any?
    private let currentLocation: () -> NSPoint
    private let onMove: (NSPoint) -> Void
    var isActive: Bool { globalToken != nil && localToken != nil }

    init(currentLocation: @escaping () -> NSPoint = { NSEvent.mouseLocation },
         onMove: @escaping (NSPoint) -> Void) {
        self.currentLocation = currentLocation
        self.onMove = onMove
    }
    @discardableResult
    func start() -> Bool {
        if isActive { return true }
        globalToken = NSEvent.addGlobalMonitorForEvents(matching: Self.eventMask) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleGlobalMouseMoved() }
        }
        localToken = NSEvent.addLocalMonitorForEvents(matching: Self.eventMask) { [weak self] event in
            MainActor.assumeIsolated { _ = self?.handleLocalMouseMoved(event) }
            return event
        }
        guard isActive else { stop(); return false }
        return true
    }
    func stop() {
        if let globalToken { NSEvent.removeMonitor(globalToken) }
        if let localToken { NSEvent.removeMonitor(localToken) }
        globalToken = nil; localToken = nil
    }
    func handleGlobalMouseMoved() {
        guard isActive else { return }
        onMove(currentLocation())
    }
    func handleLocalMouseMoved(_ event: NSEvent) -> NSEvent {
        guard isActive else { return event }
        onMove(currentLocation())
        return event
    }
}
