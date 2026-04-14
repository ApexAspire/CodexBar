import AppKit
import CodexBarCore

@MainActor
final class StackedTextStatusView: NSView {
    @MainActor
    private final class TextLineView: NSView {
        private static let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        private static let paragraphStyle: NSParagraphStyle = {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            paragraph.lineBreakMode = .byClipping
            paragraph.minimumLineHeight = 8
            paragraph.maximumLineHeight = 8
            return paragraph
        }()

        var text: String = "" {
            didSet {
                guard oldValue != self.text else { return }
                self.invalidateIntrinsicContentSize()
                self.needsDisplay = true
            }
        }

        override var isFlipped: Bool { true }

        override var intrinsicContentSize: NSSize {
            let size = self.attributedText.size()
            return NSSize(width: ceil(size.width), height: 8)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            self.attributedText.draw(in: self.bounds)
        }

        private var attributedText: NSAttributedString {
            NSAttributedString(
                string: self.text,
                attributes: [
                    .font: Self.font,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: Self.paragraphStyle,
                ])
        }
    }

    @MainActor
    private final class DotView: NSView {
        var severity: UsageSeverity = .normal {
            didSet {
                guard oldValue != self.severity else { return }
                self.needsDisplay = true
            }
        }

        override var isFlipped: Bool { true }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            StackedTextStatusView.dotColor(self.severity).setFill()
            NSBezierPath(ovalIn: self.bounds).fill()
        }
    }

    struct Content: Equatable {
        let provider: UsageProvider
        let sessionText: String
        let weeklyText: String
        let sessionSeverity: UsageSeverity
        let weeklySeverity: UsageSeverity
    }

    private static let brandSize = CGSize(width: 16, height: 16)
    private static let gap: CGFloat = 3
    private static let dotDiameter: CGFloat = 5
    private static let dotGap: CGFloat = 2
    private static let lineHeight: CGFloat = 8
    private static let totalHeight: CGFloat = 18
    private static let dotVerticalNudge: CGFloat = -1

    private let brandImageView: NSImageView
    private let sessionLabel: TextLineView
    private let weeklyLabel: TextLineView
    private let sessionDot: DotView
    private let weeklyDot: DotView

    private(set) var content: Content?

    init() {
        self.brandImageView = NSImageView(frame: .zero)
        self.sessionLabel = TextLineView(frame: .zero)
        self.weeklyLabel = TextLineView(frame: .zero)
        self.sessionDot = DotView(frame: .zero)
        self.weeklyDot = DotView(frame: .zero)
        super.init(frame: .zero)
        self.setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override var intrinsicContentSize: NSSize {
        let sessionWidth = self.sessionLabel.intrinsicContentSize.width
        let weeklyWidth = self.weeklyLabel.intrinsicContentSize.width
        return NSSize(
            width: Self.brandSize.width + Self.gap + Self.dotDiameter + Self.dotGap + max(sessionWidth, weeklyWidth),
            height: Self.totalHeight)
    }

    override func layout() {
        super.layout()

        let brandY = floor((self.bounds.height - Self.brandSize.height) / 2)
        self.brandImageView.frame = NSRect(origin: NSPoint(x: 0, y: brandY), size: Self.brandSize)

        let dotSpace = Self.dotDiameter + Self.dotGap
        let textX = Self.brandSize.width + Self.gap + dotSpace
        let textWidth = max(0, self.bounds.width - textX)
        self.sessionLabel.frame = NSRect(x: textX, y: 1, width: textWidth, height: Self.lineHeight)
        self.weeklyLabel.frame = NSRect(x: textX, y: 9, width: textWidth, height: Self.lineHeight)

        let dotX = Self.brandSize.width + Self.gap
        let dotOffsetY = round((Self.lineHeight - Self.dotDiameter) / 2)
        self.sessionDot.frame = NSRect(
            x: dotX,
            y: 1 + dotOffsetY + Self.dotVerticalNudge,
            width: Self.dotDiameter,
            height: Self.dotDiameter)
        self.weeklyDot.frame = NSRect(
            x: dotX,
            y: 9 + dotOffsetY + Self.dotVerticalNudge,
            width: Self.dotDiameter,
            height: Self.dotDiameter)
    }

    func update(with content: Content) {
        guard self.content != content else { return }
        self.content = content

        self.brandImageView.image = ProviderBrandIcon.image(for: content.provider)
        self.sessionLabel.text = content.sessionText
        self.weeklyLabel.text = content.weeklyText

        self.sessionDot.severity = content.sessionSeverity
        self.weeklyDot.severity = content.weeklySeverity

        self.invalidateIntrinsicContentSize()
        self.needsLayout = true
    }

    private func setupSubviews() {
        self.translatesAutoresizingMaskIntoConstraints = false

        self.brandImageView.imageScaling = .scaleNone
        self.brandImageView.translatesAutoresizingMaskIntoConstraints = true
        self.addSubview(self.brandImageView)

        self.sessionLabel.translatesAutoresizingMaskIntoConstraints = true
        self.weeklyLabel.translatesAutoresizingMaskIntoConstraints = true
        self.addSubview(self.sessionLabel)
        self.addSubview(self.weeklyLabel)

        self.sessionDot.translatesAutoresizingMaskIntoConstraints = true
        self.weeklyDot.translatesAutoresizingMaskIntoConstraints = true
        self.addSubview(self.sessionDot)
        self.addSubview(self.weeklyDot)
    }

    private static func dotColor(_ severity: UsageSeverity) -> NSColor {
        switch severity {
        case .normal:
            return .systemGreen
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }
}
