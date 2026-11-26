import AppKit
import PerchCore

@MainActor
extension AppController {
    func verifyDesktopHome(folder: URL) async throws {
        rebuildOverlays()
        defer {
            timer?.invalidate(); timer = nil
            for (panel, _) in overlays { panel.close() }
            overlays.removeAll()
        }
        guard let (index, home) = homeLocation else { throw EvidenceError.fixture("no visible desktop for the home fixture") }
        let (panel, view) = overlays[index]
        let artwork = view.desktopHome, bowl = artwork.bowl
        guard let canvas = panel.contentView else { throw EvidenceError.noBitmap }
        engine.perch(on: home.floor, x: home.floor.right - 80)
        render()
        let local = bowl.convert(bowl.paintedSample, to: canvas)
        let world = panel.convertPoint(toScreen: local)
        refreshPointerRouting(at: world)
        guard !panel.ignoresMouseEvents, canvas.hitTest(local) === bowl else {
            throw EvidenceError.fixture("painted bowl did not route to the native button")
        }
        refreshPointerRouting(at: NSPoint(x: home.pillowX, y: home.origin.y + 7))
        guard panel.ignoresMouseEvents else { throw EvidenceError.fixture("decorative rug intercepted a click") }
        bowl.performClick(nil)
        timer?.invalidate(); timer = nil
        guard engine.care.foodInBowl, bowl.filled else { throw EvidenceError.fixture("button did not serve food") }
        let day = Rhythm(hour: 12, quietEnabled: false)
        func advance(to phase: HomeActivity) throws {
            for _ in 0..<3000 {
                engine.tick(dt: 1.0 / 30, surfaces: [home.floor], screens: [home.screen], rhythm: day, home: home)
                if engine.homeActivity == phase { render(); return }
            }
            throw EvidenceError.fixture("pet did not reach \(phase)")
        }
        try advance(to: .eating)
        guard view.petScene.special == .dine, !engine.care.foodInBowl else { throw EvidenceError.fixture("meal was not consumed") }
        try await waitForRender()
        try captureHome(view, to: folder.appendingPathComponent("native-home-meal.png"))
        try advance(to: .napping)
        guard view.isPaused, !bowl.filled, engine.position.x == home.pillowX else { throw EvidenceError.fixture("cushion nap") }
        try await waitForRender()
        try captureHome(view, to: folder.appendingPathComponent("native-home-nap.png"))
        refreshPointerRouting(at: world)
        guard !panel.ignoresMouseEvents, canvas.hitTest(local) === bowl else { throw EvidenceError.fixture("bowl unreachable during nap") }
        preferences.homeCorner = .right; render()
        guard let moved = homeLocation?.home, moved.origin.x > home.origin.x,
              artwork.frame.minX == moved.origin.x - panel.frame.minX else { throw EvidenceError.fixture("moving the home corner") }
        bed()
        guard !panel.isVisible, artwork.isHidden else { throw EvidenceError.fixture("tuck-away left home visible") }
        print("Verified native bowl routing, click-through decor, meal, visible cushion nap, home placement and tuck-away.")
    }

    // Composite just our own two rendering layers. No window-server or desktop capture.
    private func captureHome(_ overlay: OverlayView, to url: URL) throws {
        let art = overlay.desktopHome, sprite = overlay.petScene.sprite
        guard let decor = art.bitmapImageRepForCachingDisplay(in: art.bounds),
              let frame = sprite.texture?.cgImage() else { throw EvidenceError.noBitmap }
        art.cacheDisplay(in: art.bounds, to: decor)
        let union = art.frame.union(sprite.frame)
        let inset = NSPoint(x: 12 - (union.minX - art.frame.minX), y: 10)
        let image = NSImage(size: NSSize(width: union.width + 24, height: union.maxY - art.frame.minY + 20), flipped: false) { bounds in
            NSColor(hex: "#9FB0C9").setFill(); bounds.fill()
            NSGraphicsContext.current!.imageInterpolation = .none
            decor.draw(in: NSRect(origin: inset, size: art.bounds.size), from: .zero,
                       operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
            let position = sprite.frame.offsetBy(dx: inset.x - art.frame.minX, dy: inset.y - art.frame.minY)
            NSGraphicsContext.current!.cgContext.interpolationQuality = .none
            NSGraphicsContext.current!.cgContext.draw(frame, in: position)
            return true
        }
        guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { throw EvidenceError.noBitmap }
        try png.write(to: url, options: .atomic)
    }
}

@MainActor
extension AppController {
    /// Every action's distinct frames for four trait combinations, drawn offscreen at 3×. No windows are captured.
    func captureSprites(folder: URL) throws {
        let packs = [
            PetPack(),
            PetPack(name: "Pepper", coat: "#3C3B48", earColor: "#3C3B48", markingColor: "#F4F0EA", marking: .tuxedo, ears: .pointed),
            PetPack(name: "Biscuit", coat: "#E6B67F", earColor: "#C98B55", markingColor: "#FBEFDC", marking: .none),
            PetPack(name: "Juniper", species: .cat, coat: "#727F86", earColor: "#48555E", markingColor: "#EFEDE5",
                    marking: .tuxedo, ears: .pointed, size: .small, temperament: .calm),
            PetPack(name: "Moth", species: .cat, coat: "#D9A35E", earColor: "#B9813F", markingColor: "#F6E9D2",
                    marking: .socks, ears: .floppy),
        ]
        let unit = 3, cell = 32 * unit + 8, labelWidth = 88
        let rows: [(PetPack, String, PixelSprites.Animation)] = packs.flatMap { pack in
            Action.allCases.map { (pack, $0.rawValue, PixelSprites.animation($0, species: pack.species, ears: pack.ears)) } +
                SpecialPose.allCases.map { (pack, $0.rawValue, PixelSprites.special($0, species: pack.species, ears: pack.ears)) }
        }
        let maxFrames = 4
        let width = labelWidth + maxFrames * cell + 8, height = rows.count * cell + 8
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw EvidenceError.noBitmap }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.interpolationQuality = .none
        NSColor(hex: "#9FB0C9").setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium),
                                                    .foregroundColor: NSColor(hex: "#1D2533")]
        for (row, (pack, name, animation)) in rows.enumerated() {
            let y = height - (row + 1) * cell
            ("\(pack.name) \(name)" as NSString).draw(at: NSPoint(x: 6, y: y + cell / 2 - 6), withAttributes: attrs)
            let palette = PixelPalette(pack: pack)
            for (index, art) in animation.frames.prefix(maxFrames).enumerated() {
                let image = pixelImage(palette.rgba(art), width: art.width, height: art.height)
                context.cgContext.draw(image, in: CGRect(x: labelWidth + index * cell, y: y + 4, width: 32 * unit, height: 32 * unit))
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw EvidenceError.noBitmap }
        try png.write(to: folder.appendingPathComponent("native-sprites.png"), options: .atomic)
        print("Sprite sheet: \(rows.count) action rows for \(packs.count) trait combinations.")
    }
}
