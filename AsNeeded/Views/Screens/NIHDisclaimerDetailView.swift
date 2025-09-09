import SwiftUI
import SFSafeSymbols

struct NIHDisclaimerDetailView: View {
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				// Main Attribution
				VStack(alignment: .leading, spacing: 16) {
					HStack(spacing: 12) {
						Image(systemSymbol: .buildingColumnsFill)
							.foregroundStyle(.blue)
							.font(.title)
						
						Text("Data Attribution")
							.font(.title2)
							.fontWeight(.bold)
					}
					
					Text("This product uses publicly available data from the U.S. National Library of Medicine (NLM), National Institutes of Health, Department of Health and Human Services.")
						.font(.body)
						.multilineTextAlignment(.leading)
					
					Text("NLM is not responsible for the product and does not endorse or recommend this or any other product.")
						.font(.body)
						.fontWeight(.medium)
						.foregroundColor(.secondary)
						.multilineTextAlignment(.leading)
				}
				.padding()
				.background(
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(Color.blue.opacity(0.08))
				)
				
				// Medical Information Disclaimer
				VStack(alignment: .leading, spacing: 16) {
					Text("Medical Information")
						.font(.title2)
						.fontWeight(.bold)
					
					Text("It is not the intention of NLM to provide specific medical advice, but rather to provide users with information to better understand their health and their medications.")
						.font(.body)
						.multilineTextAlignment(.leading)
					
					Text("NLM urges you to consult with a qualified physician for advice about medications.")
						.font(.body)
						.fontWeight(.medium)
						.multilineTextAlignment(.leading)
				}
				
				// About RxNorm
				VStack(alignment: .leading, spacing: 16) {
					Text("About RxNorm")
						.font(.title2)
						.fontWeight(.bold)
					
					Text("RxNorm is a normalized naming system for generic and branded drugs produced by the National Library of Medicine.")
						.font(.body)
						.multilineTextAlignment(.leading)
					
					Text("This app uses the RxNorm API to provide:")
						.font(.body)
					
					VStack(alignment: .leading, spacing: 8) {
						Label("Medication search functionality", systemSymbol: .magnifyingglass)
							.font(.body)
						
						Label("Standardized medication names", systemSymbol: .textBadgePlus)
							.font(.body)
						
						Label("Drug information and relationships", systemSymbol: .linkCircle)
							.font(.body)
					}
					
					Text("The RxNorm data is updated monthly by NLM and provides standardized names for clinical drugs and links its names to many of the drug vocabularies commonly used in pharmacy management and drug interaction software.")
						.font(.caption)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.leading)
				}
			}
			.padding()
		}
		.navigationTitle("Data Attribution")
		.navigationBarTitleDisplayMode(.large)
	}
}

#if DEBUG
#Preview {
	NavigationView {
		NIHDisclaimerDetailView()
	}
}
#endif
