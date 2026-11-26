import AppKit
import CoreGraphics
import PerchCore

extension Rect {
    init(_ rect: NSRect) { self.init(rect.minX, rect.minY, rect.width, rect.height) }
    var ns: NSRect { NSRect(x: x, y: y, width: width, height: height) }
}
@MainActor
final class WindowTracker {
    private(set) var windows: [DesktopWindow] = []
    private(set) var surfaces: [Surface] = []
    private(set) var screens: [Rect] = []
    private(set) var visible: [Rect] = []
    private(set) var fullScreenDisplays = Set<Int>()
    private(set) var readCount = 0
    private(set) var unavailable = false
    func poll(includeOwnIDs: Set<UInt32> = []) {
        screens = NSScreen.screens.map { Rect($0.frame) }
        visible = NSScreen.screens.map { Rect($0.visibleFrame) }
        guard let primary = NSScreen.screens.first else { return }
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            unavailable = true; windows = []; surfaces = Surfaces.build(windows: [], screens: screens, visible: visible); return
        }
        unavailable = false; readCount += 1
        windows = list.compactMap { info in
            guard let id = info[kCGWindowNumber as String] as? UInt32,
                  let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  pid != getpid() || includeOwnIDs.contains(id),
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.01,
                  let dictionary = info[kCGWindowBounds as String] as? [String: Double],
                  let x = dictionary["X"], let y = dictionary["Y"], let w = dictionary["Width"], let h = dictionary["Height"],
                  w > 40, h > 20 else { return nil }
            return DesktopWindow(id: id, bounds: Rect.fromCG(Rect(x, y, w, h), primaryTop: primary.frame.maxY), pid: pid)
        }
        fullScreenDisplays = []
        for (index, screen) in screens.enumerated() {
            if let front = windows.first(where: { $0.bounds.intersects(screen) }),
               front.bounds.width >= screen.width - 4, front.bounds.height >= screen.height - 4,
               front.bounds.minX <= screen.minX + 2, front.bounds.minY <= screen.minY + 2 {
                fullScreenDisplays.insert(index)
            }
        }
        surfaces = Surfaces.build(windows: windows, screens: screens, visible: visible)
    }
}
