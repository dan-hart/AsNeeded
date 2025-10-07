import SwiftUI
import SFSafeSymbols

struct NIHDisclaimerDetailView: View {
	@ScaledMetric private var mainSpacing: CGFloat = 24
	@ScaledMetric private var sectionSpacing: CGFloat = 16
	@ScaledMetric private var itemSpacing: CGFloat = 12
	@ScaledMetric private var smallSpacing: CGFloat = 8
	@ScaledMetric private var tinySpacing: CGFloat = 6
	@ScaledMetric private var tightSpacing: CGFloat = 4
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: mainSpacing) {
				// Main Attribution
				VStack(alignment: .leading, spacing: sectionSpacing) {
					HStack(spacing: itemSpacing) {
						Image(systemSymbol: .buildingColumnsFill)
							.foregroundStyle(.blue)
							.font(.title)

						Text("Medical Data Sources")
							.font(.title2)
							.fontWeight(.bold)
					}

					Text("All medication information is sourced from official U.S. government databases:")
						.font(.body)
						.multilineTextAlignment(.leading)

					VStack(alignment: .leading, spacing: smallSpacing) {
						Text("• U.S. National Library of Medicine (NLM)")
							.font(.body)
							.fontWeight(.medium)
						Text("• National Institutes of Health")
							.font(.body)
							.fontWeight(.medium)
						Text("• Department of Health and Human Services")
							.font(.body)
							.fontWeight(.medium)
					}

					Button(action: {
						if let url = URL(string: "https://www.nlm.nih.gov/") {
							UIApplication.shared.open(url)
						}
					}) {
						HStack(spacing: tightSpacing) {
							Text("Visit NIH Official Website")
								.font(.caption)
								.foregroundStyle(.accent)
								.underline()
							Image(systemSymbol: .arrowUpRightSquare)
								.font(.caption2)
								.foregroundStyle(.accent)
						}
					}
					.buttonStyle(.plain)

					Text("NLM is not responsible for the product and does not endorse or recommend this or any other product.")
						.font(.body)
						.fontWeight(.medium)
						.foregroundColor(.secondary)
						.multilineTextAlignment(.leading)
				}
				.padding(padding)
				.background(
					RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
						.fill(Color.blue.opacity(0.08))
				)

				// Medical Information Disclaimer
				VStack(alignment: .leading, spacing: sectionSpacing) {
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
				VStack(alignment: .leading, spacing: sectionSpacing) {
					Text("RxNorm Database Citation")
						.font(.title2)
						.fontWeight(.bold)

					Text("This app uses the RxNorm database, an authoritative medication terminology system maintained by the National Library of Medicine.")
						.font(.body)
						.multilineTextAlignment(.leading)

					Text("RxNorm provides:")
						.font(.body)

					VStack(alignment: .leading, spacing: smallSpacing) {
						Label("Medication search functionality", systemSymbol: .magnifyingglass)
							.font(.body)

						Label("Standardized medication names", systemSymbol: .textBadgePlus)
							.font(.body)

						Label("Drug information and relationships", systemSymbol: .linkCircle)
							.font(.body)
					}

					VStack(alignment: .leading, spacing: tinySpacing) {
						Text("Official Sources:")
							.font(.body)
							.fontWeight(.medium)

						Button(action: {
							if let url = URL(string: "https://www.nlm.nih.gov/research/umls/rxnorm/") {
								UIApplication.shared.open(url)
							}
						}) {
							HStack(spacing: tightSpacing) {
								Text("RxNorm Database Homepage")
									.font(.caption)
									.foregroundStyle(.accent)
									.underline()
								Image(systemSymbol: .arrowUpRightSquare)
									.font(.caption2)
									.foregroundStyle(.accent)
							}
						}
						.buttonStyle(.plain)

						Button(action: {
							if let url = URL(string: "https://lhncbc.nlm.nih.gov/RxNav/") {
								UIApplication.shared.open(url)
							}
						}) {
							HStack(spacing: tightSpacing) {
								Text("RxNorm API Documentation")
									.font(.caption)
									.foregroundStyle(.accent)
									.underline()
								Image(systemSymbol: .arrowUpRightSquare)
									.font(.caption2)
									.foregroundStyle(.accent)
							}
						}
						.buttonStyle(.plain)
					}

					Text("The RxNorm data is updated monthly by NLM and provides standardized names for clinical drugs and links its names to many of the drug vocabularies commonly used in pharmacy management and drug interaction software.")
						.font(.caption)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.leading)
				}
			}
			.padding(padding)
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
