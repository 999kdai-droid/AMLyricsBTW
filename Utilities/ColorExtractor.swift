import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - Color Extractor
@MainActor
final class ColorExtractor {
    
    static func extractDominantColors(from image: NSImage, maxColors: Int = 3) -> [NSColor] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return fallbackColors()
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let areaDetector = CIFilter.areaAverage()
        areaDetector.inputImage = ciImage
        areaDetector.extent = ciImage.extent
        
        guard let outputImage = areaDetector.outputImage else {
            return fallbackColors()
        }
        
        // Create a bitmap representation to extract the average color
        let extent = outputImage.extent
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                      pixelsWide: 1,
                                      pixelsHigh: 1,
                                      bitsPerSample: 8,
                                      samplesPerPixel: 4,
                                      hasAlpha: true,
                                      isPlanar: false,
                                      colorSpaceName: NSColorSpaceName.deviceRGB,
                                      bytesPerRow: 4,
                                      bitsPerPixel: 32),
              let bitmapData = bitmap.bitmapData else {
            return fallbackColors()
        }
        
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let cgColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        context.render(outputImage, toBitmap: bitmapData,
                      rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8, colorSpace: cgColorSpace)
        
        let red = CGFloat(bitmapData[0]) / 255.0
        let green = CGFloat(bitmapData[1]) / 255.0
        let blue = CGFloat(bitmapData[2]) / 255.0
        let averageColor = NSColor(red: red, green: green, blue: blue, alpha: 1.0)
        
        // Generate a palette based on the average color
        var colors = [averageColor]
        
        // Create variations
        let hsl = averageColor.toHSL()
        
        // Add a slightly lighter variation
        let lighter = NSColor(
            hue: hsl.hue,
            saturation: hsl.saturation * 0.8,
            brightness: min(1.0, hsl.brightness * 1.2),
            alpha: 1.0
        )
        colors.append(lighter)
        
        // Add a slightly darker variation
        let darker = NSColor(
            hue: hsl.hue,
            saturation: hsl.saturation * 0.9,
            brightness: max(0.0, hsl.brightness * 0.7),
            alpha: 1.0
        )
        colors.append(darker)
        
        // Adjust brightness if too dark
        colors = colors.map { adjustBrightnessIfNeeded($0) }
        
        return Array(colors.prefix(maxColors))
    }
    
    private static func adjustBrightnessIfNeeded(_ color: NSColor) -> NSColor {
        let hsl = color.toHSL()
        
        // If luminance is too low, brighten it
        if hsl.brightness < 0.2 {
            return NSColor(
                hue: hsl.hue,
                saturation: hsl.saturation,
                brightness: 0.3,
                alpha: 1.0
            )
        }
        
        return color
    }
    
    private static func fallbackColors() -> [NSColor] {
        return [
            NSColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0),
            NSColor(red: 0.3, green: 0.25, blue: 0.4, alpha: 1.0),
            NSColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 1.0)
        ]
    }
}

// MARK: - NSColor Extensions
extension NSColor {
    func toHSL() -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return (hue, saturation, brightness)
    }
    
    func toRGB() -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (red, green, blue, alpha)
    }
}

// MARK: - SwiftUI Color Extension
extension Color {
    init(nsColor: NSColor) {
        let rgb = nsColor.toRGB()
        self.init(
            .sRGB,
            red: rgb.red,
            green: rgb.green,
            blue: rgb.blue,
            opacity: rgb.alpha
        )
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("Color Extractor Preview")
            .font(.headline)
        
        if let sampleImage = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil) {
            let colors = ColorExtractor.extractDominantColors(from: sampleImage)
            
            HStack {
                ForEach(0..<colors.count, id: \.self) { index in
                    Color(nsColor: colors[index])
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                }
            }
        }
    }
    .padding()
}
