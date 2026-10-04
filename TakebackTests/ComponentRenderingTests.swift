import XCTest
import SwiftUI
@testable import Takeback

@MainActor final class ComponentRenderingTests: XCTestCase {
    func testFixedButtonHeightsAtStandardAndAX5Sizes() {
        for size in [DynamicTypeSize.large, .accessibility5] {
            let primary = UIHostingController(rootView: PrimaryButton(title:"Primary button") {}.dynamicTypeSize(size))
            XCTAssertEqual(primary.sizeThatFits(in:CGSize(width:335,height:1000)).height,60,accuracy:0.5)
            let secondary = UIHostingController(rootView: SecondaryButton(title:"Secondary button") {}.dynamicTypeSize(size))
            XCTAssertEqual(secondary.sizeThatFits(in:CGSize(width:335,height:1000)).height,52,accuracy:0.5)
        }
    }

    func testComponentRenderMatrix() async throws {
        let fixtures: [(String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            ("SE",375,667,20,0,0), ("17Pro",402,874,62,34,0), ("17ProMax",440,956,62,34,0),
            ("DuoOuter",466,678,0,34,84), ("DuoInner",890,626,32,20,0),
            ("DuoRotated",626,890,32,20,0), ("MiniPortrait",744,1133,24,20,0),
            ("MiniLandscape",1133,744,24,20,0), ("Pro13Landscape",1376,1032,24,20,0)
        ]
        for (name,w,h,top,bottom,trailing) in fixtures {
            for dark in [false,true] {
                for ax in [false,true] {
                    let content = FoundationPreview()
                        .safeAreaInset(edge:.top,spacing:0) { Color.clear.frame(height:top) }
                        .safeAreaInset(edge:.bottom,spacing:0) { Color.clear.frame(height:bottom) }
                        .safeAreaInset(edge:.trailing,spacing:0) { Color.clear.frame(width:trailing) }
                        .environment(\.colorScheme,dark ? .dark : .light)
                        .dynamicTypeSize(ax ? .accessibility5 : .large)
                    let controller = UIHostingController(rootView:content)
                    // Use a standalone offscreen host: fixture insets are explicit, not inherited from the runner's phone.
                    controller.safeAreaRegions = []
                    controller.overrideUserInterfaceStyle = dark ? .dark : .light
                    controller.view.frame = CGRect(x:0,y:0,width:w,height:h)
                    controller.view.backgroundColor = .clear
                    controller.view.setNeedsLayout()
                    controller.view.layoutIfNeeded()
                    try await Task.sleep(for:.milliseconds(40))
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    let image = UIGraphicsImageRenderer(size:CGSize(width:w,height:h),format:format).image { _ in
                        controller.view.drawHierarchy(in:controller.view.bounds,afterScreenUpdates:true)
                    }
                    let data = try XCTUnwrap(image.pngData())
                    XCTAssertGreaterThan(data.count,1000)
                    let label = "\(name)-\(dark ? "dark" : "light")-\(ax ? "AX5" : "standard")"
                    let attachment = XCTAttachment(image:image)
                    attachment.name = label
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }
}
