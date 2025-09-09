import SwiftUI
import SFSafeSymbols

struct MedicalDisclaimerView: View {
	@State private var showMoreInfo = false

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Image(systemSymbol: .exclamationmarkTriangleFill)
				.foregroundStyle(.yellow)
				.font(.title2)
			
				VStack(alignment: .leading, spacing: 4) {
					Text("This app is not a replacement for medical advice.")
						.font(.headline)
					Text("Consult a licensed medical professional before making any changes to your medication.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}

			Button {
				showMoreInfo = true
			} label: {
				Text("Read more info")
					.font(.body)
					.fontWeight(.medium)
			}
			.padding(.top, 4)
		}
		.padding()
		.background(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.fill(Color.yellow.opacity(0.09))
		)
		.accessibilityElement(children: .combine)
		.sheet(isPresented: $showMoreInfo) {
			MoreDisclaimerInfoView()
		}
	}
}

struct MoreDisclaimerInfoView: View {
	@Environment(\.dismiss) private var dismiss
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 24) {
					HStack {
						Image(systemSymbol: .exclamationmarkTriangleFill)
							.foregroundStyle(.orange)
							.font(.largeTitle)
							.symbolRenderingMode(.hierarchical)
						
						Text("Medical Disclaimer")
							.font(.largeTitle)
							.fontWeight(.bold)
							.foregroundStyle(.primary)
					}
					
					VStack(alignment: .leading, spacing: 20) {
						Text("This application does not provide medical advice, diagnosis, or treatment. All content, including text, graphics, and information, is for informational purposes only.")
							.font(.body)
							.foregroundStyle(.primary)
							.fixedSize(horizontal: false, vertical: true)
						
						Text("Always seek the advice of your physician or another qualified health provider with any questions you may have regarding a medical condition, medication, or treatment. Never disregard professional medical advice or delay seeking it because of something you have read or recorded in this app.")
							.font(.body)
							.foregroundStyle(.primary)
							.fixedSize(horizontal: false, vertical: true)
						
						VStack(alignment: .leading, spacing: 8) {
							Image(systemSymbol: .exclamationmarkTriangleFill)
								.foregroundStyle(.red)
								.font(.title2)
								.symbolRenderingMode(.hierarchical)
							
							Text("If you think you may have a medical emergency, call your doctor or emergency services immediately.")
								.font(.body)
								.fontWeight(.semibold)
								.foregroundStyle(.red)
								.fixedSize(horizontal: false, vertical: true)
						}
						.padding(16)
						.background(
							RoundedRectangle(cornerRadius: 12, style: .continuous)
								.fill(.red.opacity(0.08))
								.stroke(.red.opacity(0.2), lineWidth: 1)
						)
					}
				}
				.padding(20)
			}
			.navigationTitle("Medical Disclaimer")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Done") { dismiss() }
				}
			}
		}
	}
}

#if DEBUG
#Preview {
	MedicalDisclaimerView()
}
#endif
