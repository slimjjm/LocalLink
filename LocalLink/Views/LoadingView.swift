import SwiftUI

struct LoadingView: View {
    
    @State private var visible = false
    
    var body: some View {
        
        ZStack {
            
            AppColors.background
                .ignoresSafeArea()
            
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .opacity(visible ? 1 : 0)
                .animation(.easeIn(duration: 1), value: visible)
        }
        .onAppear {
            visible = true
        }
    }
}
