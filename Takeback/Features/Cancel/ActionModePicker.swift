import SwiftUI

/// UIKit's native segmented picker; rendered labels retain both SF Symbols and Geist.
/// SwiftUI's segmented Label drops its icon and ignores custom title fonts on iOS 17/18.
struct ActionModePicker: UIViewRepresentable {
    @Binding var selection: PaymentActionMode
    func makeUIView(context: Context) -> Control { Control() }
    func updateUIView(_ control: Control, context: Context) {
        control.onSelect = { selection = $0 == 0 ? .speedUp : .cancel }
        control.selectedSegmentIndex = selection == .speedUp ? 0 : 1
        control.isEnabled = context.environment.isEnabled
        control.setNeedsLayout()
    }
    final class Control: UISegmentedControl {
        var onSelect: ((Int) -> Void)?
        private var renderKey = ""
        private let titles = ["Speed up", "Cancel"]
        private let symbols = ["bolt", "arrow.uturn.backward"]
        init() {
            super.init(items: ["Speed up", "Cancel"])
            accessibilityIdentifier = "action.mode"
            addTarget(self, action: #selector(changed), for: .valueChanged)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        @objc private func changed() { onSelect?(selectedSegmentIndex); setNeedsLayout() }
        override func layoutSubviews() {
            super.layoutSubviews()
            let key = "\(bounds.width)-\(selectedSegmentIndex)-\(traitCollection.preferredContentSizeCategory.rawValue)-\(traitCollection.userInterfaceStyle.rawValue)"
            guard key != renderKey, bounds.width > 0 else { return }; renderKey = key
            var elements: [UIAccessibilityElement] = []
            for index in 0..<2 {
                let selected = selectedSegmentIndex == index
                let base = Geist.uiFont(14, selected ? .semibold : .regular, traits: traitCollection)
                let textSize = (titles[index] as NSString).size(withAttributes: [.font: base])
                let scale = min(1, max(0.8, (bounds.width / 2 - 20) / (textSize.width + base.pointSize + 6)))
                let font = base.withSize(base.pointSize * scale), iconSize = font.pointSize
                let size = (titles[index] as NSString).size(withAttributes: [.font: font])
                let fullSize = CGSize(width: ceil(size.width + iconSize + 6), height: ceil(size.height))
                var image: UIImage!
                traitCollection.performAsCurrent {
                    image = UIGraphicsImageRenderer(size: fullSize).image { _ in
                        UIImage(systemName: symbols[index], withConfiguration: UIImage.SymbolConfiguration(pointSize: iconSize, weight: selected ? .semibold : .regular))?
                            .withTintColor(.label, renderingMode: .alwaysOriginal)
                            .draw(in: CGRect(x: 0, y: (fullSize.height - iconSize) / 2, width: iconSize, height: iconSize))
                        (titles[index] as NSString).draw(at: CGPoint(x: iconSize + 6, y: 0), withAttributes: [.font: font, .foregroundColor: UIColor.label])
                    }.withRenderingMode(.alwaysOriginal)
                }
                image.accessibilityLabel = titles[index]
                setImage(image, forSegmentAt: index)
                let element = ActionModePicker.ModeElement(container: self) { [weak self] in
                    guard let self, self.isEnabled else { return false }
                    self.selectedSegmentIndex = index; self.changed(); return true
                }
                element.accessibilityLabel = titles[index]
                element.accessibilityTraits = selected ? [.button, .selected] : .button
                element.accessibilityFrameInContainerSpace = CGRect(x: bounds.width * CGFloat(index) / 2, y: 0, width: bounds.width / 2, height: bounds.height)
                elements.append(element)
            }
            isAccessibilityElement = false; accessibilityElements = elements
        }
    }
    private final class ModeElement: UIAccessibilityElement {
        let activate: () -> Bool
        init(container: Any, activate: @escaping () -> Bool) { self.activate = activate; super.init(accessibilityContainer: container) }
        override func accessibilityActivate() -> Bool { activate() }
    }
}
