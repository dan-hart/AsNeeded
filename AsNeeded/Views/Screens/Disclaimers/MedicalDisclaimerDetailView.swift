import SwiftUI
import SFSafeSymbols

struct MedicalDisclaimerDetailView: View {
	@ScaledMetric private var mainSpacing: CGFloat = 24
	@ScaledMetric private var sectionSpacing: CGFloat = 16
	@ScaledMetric private var itemSpacing: CGFloat = 12
	@ScaledMetric private var smallSpacing: CGFloat = 2
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var verticalPadding: CGFloat = 4
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var iconWidth: CGFloat = 24
	@ScaledMetric private var lineWidth: CGFloat = 1

	var body: some View {
		ScrollView {
            VStack(alignment: .leading, spacing: mainSpacing) {
                // Warning Section
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    HStack(spacing: itemSpacing) {
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
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.yellow.opacity(0.09))
                )

                // Full Disclaimer Text
                VStack(alignment: .leading, spacing: sectionSpacing) {
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
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.gray.opacity(0.09))
                )

                // Trusted Medical Information Sources
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    Text("Authoritative Medical Information Sources")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("For reliable, evidence-based medical information, consult these trusted healthcare organizations:")
                        .font(.body)
                        .multilineTextAlignment(.leading)

                    VStack(alignment: .leading, spacing: itemSpacing) {
                        medicalSourceLink(
                            title: "MedlinePlus",
                            subtitle: "National Library of Medicine - Consumer health information",
                            url: "https://medlineplus.gov/"
                        )

                        medicalSourceLink(
                            title: "CDC",
                            subtitle: "Centers for Disease Control and Prevention",
                            url: "https://www.cdc.gov/"
                        )

                        medicalSourceLink(
                            title: "FDA",
                            subtitle: "U.S. Food and Drug Administration - Drug safety and approvals",
                            url: "https://www.fda.gov/"
                        )

                        medicalSourceLink(
                            title: "Mayo Clinic",
                            subtitle: "Leading medical institution with patient education resources",
                            url: "https://www.mayoclinic.org/"
                        )

                        medicalSourceLink(
                            title: "WHO",
                            subtitle: "World Health Organization - Global health authority",
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
            .padding(padding)
		}
		.navigationTitle("Medical Disclaimer")
		.navigationBarTitleDisplayMode(.large)
	}

	// MARK: - Helper Functions

	private func medicalSourceLink(title: String, subtitle: String, url: String) -> some View {
		Button(action: {
			if let url = URL(string: url) {
				UIApplication.shared.open(url)
			}
		}) {
			HStack(spacing: itemSpacing) {
				Image(systemSymbol: .linkCircle)
					.font(.system(.subheadline))
					.foregroundColor(.accentColor)
					.frame(width: iconWidth)

				VStack(alignment: .leading, spacing: smallSpacing) {
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
					.font(.system(.caption))
					.foregroundColor(.secondary)
			}
			.padding(.vertical, verticalPadding)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}
}

#if DEBUG
#Preview {
	NavigationView {
		MedicalDisclaimerDetailView()
	}
}
#endif
