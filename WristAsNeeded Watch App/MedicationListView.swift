import SwiftUI

struct MedicationListView: View {
    @EnvironmentObject var sender: WCSender
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading medications...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if sender.medications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pills")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No medications")
                        .font(.headline)
                    Text("Add medications in the iPhone app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Refresh") {
                        Task {
                            await loadMedications()
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            } else {
                List {
                    ForEach(sender.medications) { medication in
                        NavigationLink(destination: MedicationDetailView(medication: medication)) {
                            MedicationRowView(medication: medication)
                        }
                    }
                }
                .refreshable {
                    await loadMedications()
                }
            }
        }
        .navigationTitle("Medications")
        .onAppear {
            Task {
                await loadMedications()
            }
        }
    }
    
    private func loadMedications() async {
        isLoading = true
        sender.sendMessage(key: "getMedications", value: "request")
        
        // Wait for response with timeout
        for _ in 0..<30 { // 3 second timeout
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            if !sender.medications.isEmpty {
                break
            }
        }
        
        isLoading = false
    }
}

struct MedicationRowView: View {
    let medication: WatchMedication
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(medication.displayName)
                .font(.headline)
                .lineLimit(2)
            
            HStack {
                Text("Qty: \(medication.quantity, specifier: "%.0f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let prescribedDoseAmount = medication.prescribedDoseAmount,
                   let prescribedUnit = medication.prescribedUnit {
                    Text("\(prescribedDoseAmount, specifier: "%.1f") \(prescribedUnit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
#Preview {
    MedicationListView()
}
#endif