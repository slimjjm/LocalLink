import SwiftUI

struct CardStyle: ViewModifier {

    var highlight: Bool = false

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                highlight ? AppColors.primary.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
    }
}
