import SwiftUI

struct StartSelectionView: View {

    @AppStorage("userType") var userType: String = ""
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    @State private var showBusinessOnboarding = false
    @State private var fadeIn = false

    var body: some View {
        NavigationStack {
            ZStack {

                // MARK: - Background
                LinearGradient(
                    colors: [Color(.systemGray6), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {

                    // MARK: - App Logo / Title
                    VStack(spacing: 8) {
                        Image(systemName: "link.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 90)
                            .foregroundColor(.blue)
                            .shadow(radius: 4)

                        Text("Welcome to LocalLink")
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)

                        Text("How can we help you today?")
                            .foregroundColor(.secondary)
                    }
                    .opacity(fadeIn ? 1 : 0)
                    .animation(.easeIn(duration: 0.8), value: fadeIn)

                    // MARK: - Selection Buttons
                    VStack(spacing: 22) {
                        
                        // BUSINESS BUTTON
                        Button {
                            userType = "business"
                            showBusinessOnboarding = true
                        } label: {
                            selectionCard(
                                icon: "briefcase.fill",
                                title: "I am a Business",
                                subtitle: "Manage bookings, services, and customers"
                            )
                        }

                        // CUSTOMER BUTTON
                        Button {
                            userType = "customer"
                            hasCompletedOnboarding = true
                        } label: {
                            selectionCard(
                                icon: "person.3.fill",
                                title: "I am a Customer",
                                subtitle: "Find local services and book instantly"
                            )
                        }
                    }
                    .opacity(fadeIn ? 1 : 0)
                    .animation(.easeIn.delay(0.4), value: fadeIn)

                    Spacer()

                    // MARK: - Debug Menu (only in DEBUG mode)
                    #if DEBUG
                    NavigationLink(destination: DebugMenuView()) {
                        Text("Open Debug Menu")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.bottom, 30)
                    }
                    #endif
                }
                .padding()
            }
            .onAppear {
                fadeIn = true
            }
            .navigationDestination(isPresented: $showBusinessOnboarding) {
                BusinessOnboardingView()
            }
        }
    }

    // MARK: - Selection Card Component
    func selectionCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
    }
}

#Preview {
    StartSelectionView()
}
