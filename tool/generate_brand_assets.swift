import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let ink = NSColor(calibratedRed: 21 / 255, green: 62 / 255, blue: 69 / 255, alpha: 1)
let teal = NSColor(calibratedRed: 23 / 255, green: 100 / 255, blue: 94 / 255, alpha: 1)
let paper = NSColor(calibratedRed: 250 / 255, green: 251 / 255, blue: 248 / 255, alpha: 1)
let pale = NSColor(calibratedRed: 222 / 255, green: 237 / 255, blue: 231 / 255, alpha: 1)
let accent = NSColor(calibratedRed: 225 / 255, green: 155 / 255, blue: 103 / 255, alpha: 1)

func roundedRect(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func drawMark(in rect: CGRect) {
    let scale = rect.width / 1024
    let left = rect.minX
    let bottom = rect.minY
    func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: left + x * scale, y: bottom + y * scale, width: width * scale, height: height * scale)
    }

    roundedRect(box(248, 182, 528, 660), radius: 70 * scale, color: paper)

    let fold = NSBezierPath()
    fold.move(to: CGPoint(x: left + 636 * scale, y: bottom + 842 * scale))
    fold.line(to: CGPoint(x: left + 776 * scale, y: bottom + 702 * scale))
    fold.line(to: CGPoint(x: left + 636 * scale, y: bottom + 702 * scale))
    fold.close()
    pale.setFill()
    fold.fill()

    roundedRect(box(326, 594, 144, 144), radius: 36 * scale, color: accent)
    roundedRect(box(381, 619, 34, 94), radius: 14 * scale, color: paper)
    roundedRect(box(351, 649, 94, 34), radius: 14 * scale, color: paper)

    roundedRect(box(510, 676, 172, 22), radius: 11 * scale, color: teal)
    roundedRect(box(510, 622, 120, 18), radius: 9 * scale, color: pale)

    let pulse = NSBezierPath()
    pulse.lineWidth = 28 * scale
    pulse.lineCapStyle = .round
    pulse.lineJoinStyle = .round
    pulse.move(to: CGPoint(x: left + 328 * scale, y: bottom + 440 * scale))
    pulse.line(to: CGPoint(x: left + 430 * scale, y: bottom + 440 * scale))
    pulse.line(to: CGPoint(x: left + 475 * scale, y: bottom + 516 * scale))
    pulse.line(to: CGPoint(x: left + 540 * scale, y: bottom + 356 * scale))
    pulse.line(to: CGPoint(x: left + 596 * scale, y: bottom + 468 * scale))
    pulse.line(to: CGPoint(x: left + 648 * scale, y: bottom + 440 * scale))
    pulse.line(to: CGPoint(x: left + 696 * scale, y: bottom + 440 * scale))
    teal.setStroke()
    pulse.stroke()

    roundedRect(box(328, 276, 368, 20), radius: 10 * scale, color: pale)
    roundedRect(box(328, 226, 248, 20), radius: 10 * scale, color: pale)
}

func render(width: Int, height: Int, draw: () -> Void) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    draw()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to relativePath: String) throws {
    let destination = root.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
}

func makeIcon(size: Int) -> NSBitmapImageRep {
    render(width: size, height: size) {
        ink.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        drawMark(in: CGRect(x: 0, y: 0, width: size, height: size))
    }
}

let iosIcons: [(String, Int)] = [
    ("Icon-App-20x20@2x.png", 40), ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29), ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87), ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80), ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120), ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-76x76@1x.png", 76), ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167), ("Icon-App-1024x1024@1x.png", 1024),
]

let appIconPath = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for (name, size) in iosIcons {
    try writePNG(makeIcon(size: size), to: "\(appIconPath)/\(name)")
}

let androidIconSizes = [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]
for (density, size) in androidIconSizes {
    try writePNG(makeIcon(size: size), to: "android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
}

for (density, size) in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)] {
    let bitmap = render(width: size, height: size) {
        let scale = CGFloat(size) / 1024
        let artworkSize = 1048 * scale
        let origin = (CGFloat(size) - artworkSize) / 2
        drawMark(in: CGRect(x: origin, y: origin, width: artworkSize, height: artworkSize))
    }
    try writePNG(bitmap, to: "android/app/src/main/res/mipmap-\(density)/ic_launcher_foreground.png")
}

let launchBitmap = render(width: 280, height: 240) {
    let iconRect = CGRect(x: 82, y: 86, width: 116, height: 116)
    roundedRect(iconRect, radius: 27, color: ink)
    drawMark(in: iconRect)

    let title = NSAttributedString(
        string: "Clinical Assistant",
        attributes: [
            .font: NSFont.systemFont(ofSize: 19, weight: .semibold),
            .foregroundColor: ink,
        ]
    )
    let titleSize = title.size()
    title.draw(at: CGPoint(x: (280 - titleSize.width) / 2, y: 42))
}

for (name, multiplier) in [("LaunchImage.png", 1), ("LaunchImage@2x.png", 2), ("LaunchImage@3x.png", 3)] {
    let size = 240 * multiplier
    let bitmap = render(width: 280 * multiplier, height: size) {
        launchBitmap.draw(in: NSRect(x: 0, y: 0, width: 280 * multiplier, height: size))
    }
    try writePNG(bitmap, to: "ios/Runner/Assets.xcassets/LaunchImage.imageset/\(name)")
}

try writePNG(launchBitmap, to: "android/app/src/main/res/drawable/launch_brand.png")
print("Generated iOS and Android app icons and launch artwork.")