import SwiftUI

/// Centralized Liquid Glass tokens — keeps the surfaces consistent.
enum GlassPalette {
    static let bubbleSourceTint = Color.accentColor.opacity(0.28)
    static let bubbleTargetTint = Color(red: 0.42, green: 0.78, blue: 1.0).opacity(0.22)
    static let toolbarTint = Color.primary.opacity(0.05)
    static let pillTint = Color.accentColor.opacity(0.18)
}

extension View {
    /// Applies a regular Liquid Glass effect inside a rounded shape.
    @ViewBuilder
    func iHGlass(cornerRadius: CGFloat = 22, tint: Color? = nil, interactive: Bool = false) -> some View {
        if let tint {
            if interactive {
                self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            if interactive {
                self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        }
    }
}
