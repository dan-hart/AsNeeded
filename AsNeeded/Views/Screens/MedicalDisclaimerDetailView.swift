import SwiftUI
import SFSafeSymbols

struct MedicalDisclaimerDetailView: View {
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				// Warning Section
				VStack(alignment: .leading, spacing: 16) {
					HStack(spacing: 12) {
						Image(systemSymbol: .exclamationmarkTriangleFill)
							.foregroundStyle(.yellow)
							.font(.title)
						
						Text("Important Notice")
							.font(.title2)
							.fontWeight(.bold)
					}
					
					Text("This application is not a replacement for professional medical advice.")
						.font(.headline)
						.foregroundColor(.primary)
					
					Text("Always consult a licensed medical professional before making any changes to your medication regimen.")
						.font(.body)
						.foregroundColor(.secondary)
				}
				.padding()
				.background(
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(Color.yellow.opacity(0.09))
				)
				
				// Full Disclaimer Text
				VStack(alignment: .leading, spacing: 16) {
					Text("Medical Disclaimer")
						.font(.title2)
						.fontWeight(.bold)
					
					Text("This application does not provide medical advice, diagnosis, or treatment. All content, including text, graphics, and information, is for informational purposes only.")
						.font(.body)
						.multilineTextAlignment(.leading)
					
					Text("Always seek the advice of your physician or another qualified health provider with any questions you may have regarding a medical condition, medication, or treatment.")
						.font(.body)
						.multilineTextAlignment(.leading)
					
					Text("Never disregard professional medical advice or delay seeking it because of something you have read or recorded in this app.")
						.font(.body)
						.fontWeight(.medium)
						.multilineTextAlignment(.leading)
					
					Text("If you think you may have a medical emergency, call your doctor or emergency services immediately.")
						.font(.body)
						.foregroundColor(.red)
						.fontWeight(.medium)
						.multilineTextAlignment(.leading)
				}
				
				// Additional Information
				VStack(alignment: .leading, spacing: 16) {
					Text("Your Responsibility")
						.font(.title2)
						.fontWeight(.bold)
					
					Text("By using this app, you acknowledge that:")
						.font(.body)
					
					VStack(alignment: .leading, spacing: 8) {
						Label("You will consult healthcare professionals for medical advice", systemSymbol: .checkmarkCircle)
							.font(.body)
						
						Label("The app is a tracking tool only, not a medical device", systemSymbol: .checkmarkCircle)
							.font(.body)
						
						Label("You are responsible for verifying medication information", systemSymbol: .checkmarkCircle)
							.font(.body)
						
						Label("You will seek immediate help in medical emergencies", systemSymbol: .checkmarkCircle)
							.font(.body)
					}
					.foregroundColor(.secondary)
				}
			}
			.padding()
		}
		.navigationTitle("Medical Disclaimer")
		.navigationBarTitleDisplayMode(.large)
	}
}

#if DEBUG
#Preview {
	NavigationView {
		MedicalDisclaimerDetailView()
	}
}
#endif