import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRMatrix {
    let width: Int
    let modules: [Bool]

    init?(payload: String) {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        let width = Int(output.extent.width)
        var pixels = [UInt8](repeating: 0, count: width * width * 4)
        CIContext().render(output, toBitmap: &pixels, rowBytes: width * 4,
                           bounds: output.extent, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        self.width = width
        self.modules = (0..<(width * width)).map { pixels[$0 * 4] < 128 }
    }
}

/// Public addresses / public transaction data only. Never pass secret key material here.
struct DotQRCode: View {
    let payload: String
    var accessibilityText = "QR code"
    var body: some View {
        if let matrix = QRMatrix(payload: payload) {
            Canvas { context, size in
                // Core Image supplies one border module; add four more for a full quiet zone.
                let unit = min(size.width, size.height) / CGFloat(matrix.width + 8)
                let origin = CGPoint(x: (size.width - CGFloat(matrix.width) * unit) / 2,
                                     y: (size.height - CGFloat(matrix.width) * unit) / 2)
                for row in 0..<matrix.width {
                    for column in 0..<matrix.width where matrix.modules[row * matrix.width + column] {
                        let rect = CGRect(x: origin.x + CGFloat(column) * unit,
                                          y: origin.y + CGFloat(row) * unit, width: unit, height: unit)
                        // Keep the three finder patterns square for reliable scanning.
                        let finder = (row <= 7 && column <= 7) ||
                            (row <= 7 && column >= matrix.width - 8) ||
                            (row >= matrix.width - 8 && column <= 7)
                        context.fill(finder ? Path(rect) : Path(ellipseIn: rect.insetBy(dx: unit * 0.06, dy: unit * 0.06)),
                                     with: .color(.black))
                    }
                }
            }
            .background(.white).aspectRatio(1, contentMode: .fit)
            .accessibilityLabel(accessibilityText)
        }
    }
}
