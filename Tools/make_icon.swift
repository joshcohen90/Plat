#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Generate a 1024×1024 Plat app icon: rounded square with an MTA-style
// "N" bullet on a subway-green field (matches the 4/5/6 bullet color we use
// throughout the app). Run from the project root:
//   swift Tools/make_icon.swift
// Output: Plat/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

let size: CGFloat = 1024
let outURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Plat/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")

guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else { fatalError("could not make CGContext") }

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// Background: vertical gradient using two MTA palette greens for visual depth.
let bgTop    = CGColor(srgbRed: 0.00, green: 0.65, blue: 0.40, alpha: 1)  // brighter green
let bgBottom = CGColor(srgbRed: 0.00, green: 0.50, blue: 0.30, alpha: 1)  // darker green

let gradient = CGGradient(colorsSpace: cs, colors: [bgTop, bgBottom] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: 0, y: 0),
                       options: [])

// Soft inner highlight in the upper-left for a touch of dimension.
let highlight = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.18)
let highlightGradient = CGGradient(colorsSpace: cs,
                                   colors: [highlight, CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                                   locations: [0, 1])!
ctx.drawRadialGradient(highlightGradient,
                       startCenter: CGPoint(x: size * 0.25, y: size * 0.85),
                       startRadius: 0,
                       endCenter: CGPoint(x: size * 0.25, y: size * 0.85),
                       endRadius: size * 0.55,
                       options: [])

// Center bullet — white circle.
let bulletDiameter = size * 0.62
let bulletRect = CGRect(
    x: (size - bulletDiameter) / 2,
    y: (size - bulletDiameter) / 2,
    width: bulletDiameter, height: bulletDiameter
)
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
ctx.fillEllipse(in: bulletRect)

// "N" character inside the bullet, in the same green as the background top.
let n: NSString = "N"
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: bulletDiameter * 0.62, weight: .black),
    .foregroundColor: NSColor(red: 0.00, green: 0.55, blue: 0.34, alpha: 1)
]
let textSize = n.size(withAttributes: attrs)
let textRect = CGRect(
    x: (size - textSize.width) / 2,
    y: (size - textSize.height) / 2 + size * 0.005,   // tiny optical recenter
    width: textSize.width,
    height: textSize.height
)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
n.draw(in: textRect, withAttributes: attrs)
NSGraphicsContext.restoreGraphicsState()

// Encode + write.
guard let cgImage = ctx.makeImage() else { fatalError("image render failed") }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
try png.write(to: outURL)
print("→ wrote \(outURL.path)")
