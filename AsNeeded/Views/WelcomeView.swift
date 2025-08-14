import SwiftUI

struct WelcomeView: View {
    /// Called when user chooses to continue into the app.
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 10) {
                Image(systemName: "pills")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.accentColor)
                Text("Welcome to AsNeeded!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("A private, secure, and easy way to track your as-needed medications.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Getting started is simple:")
                    .font(.headline)
                Text("1. Open the Health app.")
                    .font(.body)
                Text("2. Tap the Magnifying Glass icon to Search.")
                    .font(.body)
                Text("3. Search for 'Medications' and select it.")
                    .font(.body)
                Text("4. Tap 'Add Medication' to add your medication.")
                    .font(.body)
                Text("5. Once added, return here to view & manage.")
                    .font(.body)
            }
            
            VStack(spacing: 16) {
                Button(action: openHealthAppToMedication) {
                    Label("Open Health App", systemImage: "cross.case.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: onContinue) {
                    Label("Continue — I'm set up!", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func openHealthAppToMedication() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        }
    }
}

#if DEBUG
#Preview {
    WelcomeView(onContinue: {})
}
#endif
