import SwiftUI
import SFSafeSymbols

struct MedicalDisclaimerView: View {
	@ScaledMetric private var spacing: CGFloat = 8
	@ScaledMetric private var smallSpacing: CGFloat = 4
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12

	@State private var showMoreInfo = false

	var body: some View {
		VStack(alignment: .leading, spacing: spacing) {
			Image(systemSymbol: .exclamationmarkTriangleFill)
				.foregroundStyle(.yellow)
				.font(.title2)

				VStack(alignment: .leading, spacing: smallSpacing) {
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
			.padding(.top, smallSpacing)
		}
		.padding(padding)
		.background(
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.fill(Color.yellow.opacity(0.09))
		)
		.accessibilityElement(children: .combine)
		.sheet(isPresented: $showMoreInfo) {
			MoreDisclaimerInfoView()
		}
	}
}

struct MoreDisclaimerInfoView: View {
	@ScaledMetric private var mainSpacing: CGFloat = 24
	@ScaledMetric private var sectionSpacing: CGFloat = 20
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var listSpacing: CGFloat = 12
	@ScaledMetric private var smallSpacing: CGFloat = 8
	@ScaledMetric private var tinySpacing: CGFloat = 4
	@ScaledMetric private var tightestSpacing: CGFloat = 2
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var outerPadding: CGFloat = 20
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var iconWidth: CGFloat = 24
	@ScaledMetric private var lineWidth: CGFloat = 1

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: mainSpacing) {
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
					
					VStack(alignment: .leading, spacing: sectionSpacing) {
						Text("This application does not provide medical advice, diagnosis, or treatment. All content, including text, graphics, and information, is for informational purposes only.")
							.font(.body)
							.foregroundStyle(.primary)
							.fixedSize(horizontal: false, vertical: true)
						
						Text("Always seek the advice of your physician or another qualified health provider with any questions you may have regarding a medical condition, medication, or treatment. Never disregard professional medical advice or delay seeking it because of something you have read or recorded in this app.")
							.font(.body)
							.foregroundStyle(.primary)
							.fixedSize(horizontal: false, vertical: true)
						
						VStack(alignment: .leading, spacing: smallSpacing) {
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
						.padding(padding)
						.background(
							RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
								.fill(.red.opacity(0.08))
								.stroke(.red.opacity(0.2), lineWidth: lineWidth)
						)

						// Authoritative Medical Information Sources
						VStack(alignment: .leading, spacing: itemSpacing) {
							Text("Trusted Medical Information Sources")
								.font(.headline)
								.fontWeight(.bold)

							Text("For accurate medical information, consult these authoritative sources:")
								.font(.body)

							VStack(alignment: .leading, spacing: listSpacing) {
								medicalSourceLink(
									title: "MedlinePlus (NIH)",
									subtitle: "Reliable health information from the National Library of Medicine",
									url: "https://medlineplus.gov/"
								)

								medicalSourceLink(
									title: "CDC - Centers for Disease Control",
									subtitle: "Public health information and disease prevention",
									url: "https://www.cdc.gov/"
								)

								medicalSourceLink(
									title: "FDA - U.S. Food & Drug Administration",
									subtitle: "Drug safety and approved medications",
									url: "https://www.fda.gov/"
								)

								medicalSourceLink(
									title: "Mayo Clinic",
									subtitle: "Trusted medical information and health resources",
									url: "https://www.mayoclinic.org/"
								)

								medicalSourceLink(
									title: "WHO - World Health Organization",
									subtitle: "Global health information and guidelines",
									url: "https://www.who.int/"
								)
							}
						}
						.padding(padding)
						.background(
							RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
								.fill(Color.blue.opacity(0.05))
								.stroke(Color.blue.opacity(0.2), lineWidth: lineWidth)
						)
					}
				}
				.padding(outerPadding)
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

	// MARK: - Helper Functions

	private func medicalSourceLink(title: String, subtitle: String, url: String) -> some View {
		Button(action: {
			if let url = URL(string: url) {
				UIApplication.shared.open(url)
			}
		}) {
			HStack(spacing: listSpacing) {
				Image(systemSymbol: .linkCircle)
					.font(.subheadline)
					.foregroundColor(.accentColor)
					.frame(width: iconWidth)

				VStack(alignment: .leading, spacing: tightestSpacing) {
					Text(title)
						.font(.body)
						.fontWeight(.medium)
						.foregroundColor(.primary)
						.multilineTextAlignment(.leading)

					Text(subtitle)
						.font(.caption)
						.foregroundColor(.secondary)
						.multilineTextAlignment(.leading)
				}

				Spacer()

				Image(systemSymbol: .arrowUpRightSquare)
					.font(.caption)
					.foregroundColor(.secondary)
			}
			.padding(.vertical, tinySpacing)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}
}

#if DEBUG
#Preview {
	MedicalDisclaimerView()
}
#endif
