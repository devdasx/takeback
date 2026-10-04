import Foundation
import CoreImage
import ImageIO
// Public scalar-one test vector only. This is a macOS test-fixture generator, not app code.
precondition(CommandLine.arguments.count == 2, "Provide the output PNG path")
let filter = CIFilter(name: "CIQRCodeGenerator")!
filter.setValue(Data((String(repeating: "0", count: 63) + "1").utf8), forKey: "inputMessage")
let qr = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 16, y: 16))
let image = CIContext().createCGImage(qr, from: qr.extent)!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
assert(CGImageDestinationFinalize(destination))
