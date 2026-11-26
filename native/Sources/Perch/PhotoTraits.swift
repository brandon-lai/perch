import AppKit
import Vision
import ImageIO
import CoreVideo

enum PhotoError: LocalizedError {
    case count, unreadable, noPet, insufficientMask, maskFormat
    var errorDescription: String? {
        switch self {
        case .count: "Choose 3–10 photos together. Side, front and face views work best."
        case .unreadable: "A chosen photo could not be decoded. Try a JPEG, PNG or HEIC."
        case .noPet: "Vision found no foreground subject in a photo. Choose clearer photos, or use the editable stock traits."
        case .insufficientMask: "Too little foreground color was found. Try a closer, well-lit photo or edit the traits manually."
        case .maskFormat: "Vision returned an unsupported foreground mask. Please edit the traits manually."
        }
    }
}
struct PhotoTraits: Sendable {
    var coat: String
    var ear: String
    var count: Int
    static func extract(urls: [URL]) throws -> PhotoTraits {
        guard (3...10).contains(urls.count) else { throw PhotoError.count }
        var bins: [Int: Int] = [:]
        for url in urls {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 768,
                    kCGImageSourceCreateThumbnailWithTransform: true
                  ] as CFDictionary) else { throw PhotoError.unreadable }
            let handler = VNImageRequestHandler(cgImage: image)
            let request = VNGenerateForegroundInstanceMaskRequest()
            try handler.perform([request])
            guard let result = request.results?.first, !result.allInstances.isEmpty else { throw PhotoError.noPet }
            let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            CVPixelBufferLockBaseAddress(mask, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
            guard CVPixelBufferGetPixelFormatType(mask) == kCVPixelFormatType_OneComponent32Float,
                  let base = CVPixelBufferGetBaseAddress(mask) else { throw PhotoError.maskFormat }
            let w = image.width, h = image.height
            var rgba = [UInt8](repeating: 0, count: w * h * 4)
            guard let context = CGContext(data: &rgba, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PhotoError.unreadable }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            let mw = CVPixelBufferGetWidth(mask), mh = CVPixelBufferGetHeight(mask)
            let stride = CVPixelBufferGetBytesPerRow(mask)
            var found = 0
            for y in Swift.stride(from: 0, to: h, by: 4) {
                let row = base.advanced(by: min(mh - 1, y * mh / h) * stride).assumingMemoryBound(to: Float.self)
                for x in Swift.stride(from: 0, to: w, by: 4) where row[min(mw - 1, x * mw / w)] > 0.75 {
                    let i = (y * w + x) * 4
                    let bin = (Int(rgba[i]) / 32 << 6) | (Int(rgba[i + 1]) / 32 << 3) | Int(rgba[i + 2]) / 32
                    bins[bin, default: 0] += 1; found += 1
                }
            }
            guard found >= 30 else { throw PhotoError.insufficientMask }
        }
        let ranked = bins.sorted { $0.value > $1.value }
        guard let dominant = ranked.first else { throw PhotoError.insufficientMask }
        func color(_ bin: Int) -> String {
            String(format: "#%02X%02X%02X", (bin >> 6) * 32 + 16, ((bin >> 3) & 7) * 32 + 16, (bin & 7) * 32 + 16)
        }
        let dark = ranked.prefix(12).min {
            ($0.key >> 6) + (($0.key >> 3) & 7) + ($0.key & 7) <
            ($1.key >> 6) + (($1.key >> 3) & 7) + ($1.key & 7)
        }!
        return PhotoTraits(coat: color(dominant.key), ear: color(dark.key), count: urls.count)
    }
}
