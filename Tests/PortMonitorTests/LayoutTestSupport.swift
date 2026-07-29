import AppKit
import SwiftUI

protocol LayoutTestVisitor {
    mutating func visit(type: Any.Type)
    mutating func visit(value: Any)
}

extension LayoutTestVisitor {
    mutating func walk(_ value: Any) {
        visit(type: Swift.type(of: value))
        visit(value: value)

        for child in Mirror(reflecting: value).children {
            walk(child.value)
        }
    }
}

@MainActor
enum IntrinsicSizeProbe {
    static func height<Content: View>(of view: Content, width: CGFloat = 340) -> CGFloat {
        let hostingView = NSHostingView(rootView: view.frame(width: width))
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: 1)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize.height
    }
}
