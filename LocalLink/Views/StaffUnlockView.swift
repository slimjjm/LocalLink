import SwiftUI

struct StaffUnlockView: View {
    
    let businessId: String
    let onSuccess: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = StaffUnlockViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // MARK: - Header
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unlock more staff")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose a plan to unlock more team members. Billing is handled securely through Apple.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // MARK: - Content
                
                if vm.isLoadingProducts {
                    
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading plans…")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                    
                } else {
                    
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(StaffUnlockViewModel.SeatPlan.allCases) { plan in
                                planCard(plan)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Error
                
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // MARK: - Restore
                
                Button {
                    Task {
                        let restored = await vm.restorePurchases()
                        if restored {
                            onSuccess()
                        }
                    }
                } label: {
                    Text("Restore Purchases")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(vm.isWorking)
            }
            .padding()
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await vm.configure(businessId: businessId)
            }
        }
    }
    
    // MARK: - Plan Card
    
    @ViewBuilder
    private func planCard(_ plan: StaffUnlockViewModel.SeatPlan) -> some View {
        
        let product = vm.product(for: plan)
        let isActive = vm.isActive(plan: plan)
        
        VStack(alignment: .leading, spacing: 12) {
            
            // Title + price
            
            HStack(alignment: .top) {
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.title)
                        .font(.headline)
                    
                    if let badge = plan.badge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                Text(product?.displayPrice ?? "—")
                    .font(.title3.weight(.semibold))
            }
            
            // Description
            
            Text("Adds \(plan.extraSeats) extra staff slot\(plan.extraSeats == 1 ? "" : "s") to your business.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Button
            
            Button {
                Task {
                    let result = await vm.purchase(plan: plan)
                    
                    switch result {
                    case .completed:
                        onSuccess()
                        dismiss()
                        
                    case .canceled:
                        break
                        
                    case .failed:
                        break
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    
                    if vm.isWorking {
                        ProgressView()
                    } else if isActive {
                        Text("Current Plan")
                            .fontWeight(.semibold)
                    } else {
                        Text("Choose Plan")
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isWorking || product == nil || isActive)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}
