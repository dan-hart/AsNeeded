import SFSafeSymbols
import SwiftUI

struct MedicalDisclaimerDetailView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let mainSpacing: CGFloat = 24
	private let sectionSpacing: CGFloat = 16
	private let itemSpacing: CGFloat = 12
	private let smallSpacing: CGFloat = 2
	private let padding: CGFloat = 16
	private let verticalPadding: CGFloat = 4
	private let cornerRadius: CGFloat = 12
	private let iconWidth: CGFloat = 24
	private let lineWidth: CGFloat = 1

    var body: some View {
        VerticalOnlyScrollView {
            VStack(alignment: .leading, spacing: mainSpacing) {
                // Warning Section
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    HStack(spacing: itemSpacing) {
                        Image(systemSymbol: .exclamationmarkTriangleFill)
                            .foregroundStyle(.yellow)
                            .font(.customFont(fontFamily, style: .title))

                        Text("Important Notice")
                            .font(.customFont(fontFamily, style: .title2))
                            .fontWeight(.bold)
                    }

                    Text("This application is not a replacement for professional medical advice.")
                        .font(.customFont(fontFamily, style: .headline))
                        .foregroundColor(.primary)

                    Text("Always consult a licensed medical professional before making any changes to your medication regimen.")
                        .font(.customFont(fontFamily, style: .body))
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
                        .font(.customFont(fontFamily, style: .title2))
                        .fontWeight(.bold)

                    Text("This application does not provide medical advice, diagnosis, or treatment. All content, including text, graphics, and information, is for informational purposes only.")
                        .font(.customFont(fontFamily, style: .body))
                        .multilineTextAlignment(.leading)

                    Text("Always seek the advice of your physician or another qualified health provider with any questions you may have regarding a medical condition, medication, or treatment.")
                        .font(.customFont(fontFamily, style: .body))
                        .multilineTextAlignment(.leading)

                    Text("Never disregard professional medical advice or delay seeking it because of something you have read or recorded in this app.")
                        .font(.customFont(fontFamily, style: .body))
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)

                    Text("If you think you may have a medical emergency, call your doctor or emergency services immediately.")
                        .font(.customFont(fontFamily, style: .body))
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
                        .font(.customFont(fontFamily, style: .title2))
                        .fontWeight(.bold)

                    Text("For reliable, evidence-based medical information, consult these trusted healthcare organizations:")
                        .font(.customFont(fontFamily, style: .body))
                        .multilineTextAlignment(.leading)

                    VStack(alignment: .leading, spacing: itemSpacing) {
                        medicalSourceLink(
                            title: String(localized: "MedlinePlus"),
                            subtitle: String(localized: "National Library of Medicine - Consumer health information"),
                            url: "https://medlineplus.gov/"
                        )

                        medicalSourceLink(
                            title: String(localized: "CDC"),
                            subtitle: String(localized: "Centers for Disease Control and Prevention"),
                            url: "https://www.cdc.gov/"
                        )

                        medicalSourceLink(
                            title: String(localized: "FDA"),
                            subtitle: String(localized: "U.S. Food and Drug Administration - Drug safety and approvals"),
                            url: "https://www.fda.gov/"
                        )

                        medicalSourceLink(
                            title: String(localized: "Mayo Clinic"),
                            subtitle: String(localized: "Leading medical institution with patient education resources"),
                            url: "https://www.mayoclinic.org/"
                        )

                        medicalSourceLink(
                            title: String(localized: "WHO"),
                            subtitle: String(localized: "World Health Organization - Global health authority"),
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
        .customNavigationTitle("Medical Disclaimer", displayMode: .large)
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
                    .font(.customFont(fontFamily, style: .subheadline))
                    .foregroundColor(.accent)
                    .frame(width: iconWidth)

                VStack(alignment: .leading, spacing: smallSpacing) {
                    Text(title)
                        .font(.customFont(fontFamily, style: .body))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemSymbol: .arrowUpRightSquare)
                    .font(.customFont(fontFamily, style: .caption))
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
