import SwiftUI

struct PrimaryButton: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppColors.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

struct SecondaryButton: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppColors.primary.opacity(0.15))
            .foregroundColor(AppColors.primary)
            .cornerRadius(12)
    }
}

extension View {

    func primaryButton() -> some View {
        modifier(PrimaryButton())
    }

    func secondaryButton() -> some View {
        modifier(SecondaryButton())
    }
}
