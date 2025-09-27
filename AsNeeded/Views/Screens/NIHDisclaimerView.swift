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
					Text("Medical Data Source")
						.font(.headline)

					Text("Medication information provided by:")
						.font(.subheadline)
						.foregroundStyle(.secondary)

					Text("U.S. National Library of Medicine (NLM)\nNational Institutes of Health")
						.font(.subheadline)
						.fontWeight(.medium)
						.foregroundStyle(.primary)
					
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
						Text("Medical Information Sources")
							.font(.title2)
							.fontWeight(.bold)

						Text("All medication information in this app is sourced from:")
							.font(.body)
							.multilineTextAlignment(.leading)

						VStack(alignment: .leading, spacing: 8) {
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
							HStack(spacing: 4) {
								Text("Visit NIH Official Website")
									.font(.caption)
									.foregroundStyle(.accent)
									.underline()
								Image(systemSymbol: .arrowUpRightSquare)
									.font(.system(.caption2))
									.foregroundStyle(.accent)
							}
						}
						.buttonStyle(.plain)

						Text("NLM is not responsible for the product and does not endorse or recommend this or any other product.")
							.font(.body)
							.fontWeight(.medium)
							.foregroundStyle(.secondary)
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
						Text("About RxNorm Database")
							.font(.title2)
							.fontWeight(.bold)

						Text("This app uses the RxNorm database and API, a comprehensive medication terminology system:")
							.font(.body)
							.multilineTextAlignment(.leading)

						VStack(alignment: .leading, spacing: 8) {
							Text("• Developed and maintained by NLM")
								.font(.body)
							Text("• Contains standardized medication names")
								.font(.body)
							Text("• Updated monthly with latest drug information")
								.font(.body)
							Text("• Used by healthcare systems worldwide")
								.font(.body)
						}

						Button(action: {
							if let url = URL(string: "https://lhncbc.nlm.nih.gov/RxNav/") {
								UIApplication.shared.open(url)
							}
						}) {
							HStack(spacing: 4) {
								Text("RxNorm API Documentation")
									.font(.caption)
									.foregroundStyle(.accent)
									.underline()
								Image(systemSymbol: .arrowUpRightSquare)
									.font(.system(.caption2))
									.foregroundStyle(.accent)
							}
						}
						.buttonStyle(.plain)

						Button(action: {
							if let url = URL(string: "https://www.nlm.nih.gov/research/umls/rxnorm/") {
								UIApplication.shared.open(url)
							}
						}) {
							HStack(spacing: 4) {
								Text("RxNorm Database Homepage")
									.font(.caption)
									.foregroundStyle(.accent)
									.underline()
								Image(systemSymbol: .arrowUpRightSquare)
									.font(.system(.caption2))
									.foregroundStyle(.accent)
							}
						}
						.buttonStyle(.plain)
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

#if DEBUG
#Preview {
    NIHFullDisclaimerView()
}
#endif
