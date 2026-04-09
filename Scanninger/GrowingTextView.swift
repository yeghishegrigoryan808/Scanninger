//
//  GrowingTextView.swift
//  Scanninger
//

import SwiftUI
import UIKit

// MARK: - SwiftUI wrapper

/// Multiline `UITextView` that grows vertically with content (Return inserts newlines). Styled for grouped `Form` rows.
struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    /// Matches a typical single-line grouped `Form` row (~36pt content) more closely than the old 44pt floor.
    var minHeight: CGFloat = 36
    var maxHeight: CGFloat = 240
    @Binding var measuredHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> GrowingTextInputView {
        let view = GrowingTextInputView()
        let tv = view.textView
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textColor = .label
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.keyboardType = .default
        tv.returnKeyType = .default
        tv.autocorrectionType = .default
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainer.widthTracksTextView = true
        tv.textContainerInset = GrowingTextInputView.textContainerInset
        tv.text = text
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.showsHorizontalScrollIndicator = false

        let ph = view.placeholderLabel
        ph.text = placeholder
        ph.textColor = .placeholderText
        ph.font = tv.font
        ph.numberOfLines = 0
        ph.isUserInteractionEnabled = false

        view.onBoundsChange = { [weak coordinator = context.coordinator] in
            coordinator?.scheduleHeightRecalculation()
        }

        context.coordinator.textView = tv
        context.coordinator.placeholderLabel = ph
        context.coordinator.inputView = view

        view.updatePlaceholderVisibility(text: text)
        context.coordinator.scheduleHeightRecalculation()
        return view
    }

    func updateUIView(_ uiView: GrowingTextInputView, context: Context) {
        context.coordinator.parent = self
        let tv = uiView.textView
        if tv.text != text {
            tv.text = text
        }
        uiView.placeholderLabel.text = placeholder
        uiView.placeholderLabel.font = tv.font
        uiView.updatePlaceholderVisibility(text: text)
        context.coordinator.scheduleHeightRecalculation()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView
        weak var textView: UITextView?
        weak var placeholderLabel: UILabel?
        weak var inputView: GrowingTextInputView?

        init(_ parent: GrowingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            inputView?.updatePlaceholderVisibility(text: textView.text ?? "")
            scheduleHeightRecalculation()
        }

        func scheduleHeightRecalculation() {
            DispatchQueue.main.async { [weak self] in
                self?.recalculateHeight()
            }
        }

        private func recalculateHeight() {
            guard let textView = textView, let container = inputView else { return }
            let width = container.bounds.width
            guard width > 8 else { return }
            textView.layoutIfNeeded()

            let fitted = textView.sizeThatFits(
                CGSize(width: width, height: .greatestFiniteMagnitude)
            )
            var h = max(parent.minHeight, fitted.height)
            if h > parent.maxHeight {
                h = parent.maxHeight
                textView.isScrollEnabled = true
            } else {
                textView.isScrollEnabled = false
            }

            if abs(h - parent.measuredHeight) > 0.5 {
                parent.measuredHeight = h
            }
        }
    }
}

// MARK: - UIView container

/// UIKit container for layout + placeholder; must be `internal` (not `private`) so `UIViewRepresentable` methods
/// that return/take this type and `Coordinator.inputView` satisfy Swift access rules.
final class GrowingTextInputView: UIView {
    /// Tighter than default UITextView insets so one-line height aligns with `TextField` rows (was 11/11).
    static let textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

    let textView = UITextView()
    let placeholderLabel = UILabel()

    var onBoundsChange: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true

        textView.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textView)
        addSubview(placeholderLabel)

        let inset = Self.textContainerInset
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: inset.top),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: inset.left),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor, constant: -inset.right),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onBoundsChange?()
    }

    func updatePlaceholderVisibility(text: String) {
        let empty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        placeholderLabel.isHidden = !empty
    }
}
