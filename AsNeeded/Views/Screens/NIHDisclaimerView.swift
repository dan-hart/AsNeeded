import SwiftUI
import SFSafeSymbols

struct NIHDisclaimerView: View {
	@State private var showFullDisclaimer = false
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(alignment: .top, spacing: 12) {
				Image(systemSymbol: .infoCircleFill)
					.foregroundStyle(.blue.opacity(0.8))
					.font(.title2)
				
				VStack(alignment: .leading, spacing: 8) {
					Text("Data Attribution")
						.font(.headline)
					
					Text("This product uses publicly available data from the U.S. National Library of Medicine (NLM), National Institutes of Health.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
					
					Button {
						showFullDisclaimer = true
					} label: {
						Text("View full disclaimer")
							.font(.body)
							.fontWeight(.medium)
					}
					.padding(.top, 4)
				}
			}
			.padding()
			.background(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.fill(Color.blue.opacity(0.08))
			)
		}
		.accessibilityElement(children: .combine)
		.sheet(isPresented: $showFullDisclaimer) {
			NIHFullDisclaimerView()
		}
	}
}

struct NIHFullDisclaimerView: View {
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 24) {
					VStack(alignment: .leading, spacing: 16) {
						Text("NIH/NLM Data Attribution")
							.font(.title2)
							.fontWeight(.bold)
						
						Text("This product uses publicly available data from the U.S. National Library of Medicine (NLM), National Institutes of Health, Department of Health and Human Services; NLM is not responsible for the product and does not endorse or recommend this or any other product.")
							.font(.body)
							.multilineTextAlignment(.leading)
					}
					
					VStack(alignment: .leading, spacing: 16) {
						Text("Medical Information Disclaimer")
							.font(.title2)
							.fontWeight(.bold)
						
						Text("It is not the intention of NLM to provide specific medical advice, but rather to provide users with information to better understand their health and their medications. NLM urges you to consult with a qualified physician for advice about medications.")
							.font(.body)
							.multilineTextAlignment(.leading)
					}
					
					VStack(alignment: .leading, spacing: 16) {
						Text("About RxNorm")
							.font(.title2)
							.fontWeight(.bold)
						
						Text("RxNorm is a normalized naming system for generic and branded drugs produced by the National Library of Medicine. This app uses the RxNorm API to provide medication search and information features.")
							.font(.body)
							.multilineTextAlignment(.leading)
						
						Text("The RxNorm data is updated monthly by NLM and provides standardized names for clinical drugs and links its names to many of the drug vocabularies commonly used in pharmacy management and drug interaction software.")
							.font(.body)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.leading)
					}
				}
				.padding()
			}
			.navigationTitle("NIH Data Attribution")
			.navigationBarTitleDisplayMode(.large)
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
	NIHDisclaimerView()
}
#endif