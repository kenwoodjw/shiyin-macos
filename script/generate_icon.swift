import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red, green, blue, alpha])!
}

let background = CGPath(roundedRect: CGRect(x: 24, y: 24, width: 976, height: 976),
                        cornerWidth: 220, cornerHeight: 220, transform: nil)
context.addPath(background)
context.clip()
let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [color(0.88, 0.92, 0.85), color(0.44, 0.61, 0.49)] as CFArray,
                          locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

context.setFillColor(color(0.09, 0.12, 0.10))
context.fillEllipse(in: CGRect(x: 145, y: 145, width: 734, height: 734))
for inset in stride(from: 174, through: 360, by: 19) {
    let value = CGFloat(inset)
    context.setStrokeColor(color(0.75, 0.83, 0.75, 0.17))
    context.setLineWidth(2.5)
    context.strokeEllipse(in: CGRect(x: value, y: value, width: 1024 - 2 * value, height: 1024 - 2 * value))
}
context.setFillColor(color(0.68, 0.78, 0.66))
context.fillEllipse(in: CGRect(x: 361, y: 361, width: 302, height: 302))
context.setFillColor(color(0.25, 0.39, 0.29))
context.fillEllipse(in: CGRect(x: 478, y: 478, width: 68, height: 68))

let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
