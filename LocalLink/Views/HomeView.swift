import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to the Home Screen!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("This is where users will explore services.")
                .foregroundColor(.gray)
        }
        .padding()
    }
}

#Preview {
    HomeView()
}

