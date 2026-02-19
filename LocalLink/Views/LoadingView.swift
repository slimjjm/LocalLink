import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
        }
    }
}
