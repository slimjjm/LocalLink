import SwiftUI

struct CardStyle: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(
                color: .black.opacity(0.06),
                radius: 6,
                x: 0,
                y: 2
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
