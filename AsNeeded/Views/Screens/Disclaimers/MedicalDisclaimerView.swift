import SFSafeSymbols
import SwiftUI

struct MedicalDisclaimerView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let spacing: CGFloat = 8
	private let smallSpacing: CGFloat = 4
	private let padding: CGFloat = 16
	private let cornerRadius: CGFloat = 12

    @State private var showMoreInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Image(systemSymbol: .exclamationmarkTriangleFill)
                .foregroundStyle(.yellow)
                .font(.customFont(fontFamily, style: .title2))

            VStack(alignment: .leading, spacing: smallSpacing) {
                Text("This app is not a replacement for medical advice.")
                    .font(.customFont(fontFamily, style: .headline))
                Text("Consult a licensed medical professional before making any changes to your medication.")
                    .font(.customFont(fontFamily, style: .subheadline))
                    .foregroundStyle(.secondary)
            }

            Button {
                showMoreInfo = true
            } label: {
                Text("Read more info")
                    .font(.customFont(fontFamily, style: .body))
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
	@Environment(\.fontFamily) private var fontFamily
	private let mainSpacing: CGFloat = 24
	private let sectionSpacing: CGFloat = 20
	private let itemSpacing: CGFloat = 16
	private let listSpacing: CGFloat = 12
	private let smallSpacing: CGFloat = 8
	private let tinySpacing: CGFloat = 4
	private let tightestSpacing: CGFloat = 2
	private let padding: CGFloat = 16
	private let outerPadding: CGFloat = 20
	private let cornerRadius: CGFloat = 12
	private let iconWidth: CGFloat = 24
	private let lineWidth: CGFloat = 1

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: mainSpacing) {
                    HStack {
                        Image(systemSymbol: .exclamationmarkTriangleFill)
                            .foregroundStyle(.orange)
                            .font(.customFont(fontFamily, style: .largeTitle))
                            .symbolRenderingMode(.hierarchical)

                        Text("Medical Disclaimer")
                            .font(.customFont(fontFamily, style: .largeTitle))
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        Text("This application does not provide medical advice, diagnosis, or treatment. All content, including text, graphics, and information, is for informational purposes only.")
                            .font(.customFont(fontFamily, style: .body))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Always seek the advice of your physician or another qualified health provider with any questions you may have regarding a medical condition, medication, or treatment. Never disregard professional medical advice or delay seeking it because of something you have read or recorded in this app.")
                            .font(.customFont(fontFamily, style: .body))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: smallSpacing) {
                            Image(systemSymbol: .exclamationmarkTriangleFill)
                                .foregroundStyle(.red)
                                .font(.customFont(fontFamily, style: .title2))
                                .symbolRenderingMode(.hierarchical)

                            Text("If you think you may have a medical emergency, call your doctor or emergency services immediately.")
                                .font(.customFont(fontFamily, style: .body))
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
                                .font(.customFont(fontFamily, style: .headline))
                                .fontWeight(.bold)

                            Text("For accurate medical information, consult these authoritative sources:")
                                .font(.customFont(fontFamily, style: .body))

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
            .customNavigationTitle("Medical Disclaimer")
            .toolbar {
                Button(role: .close) {
                    dismiss()
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
                    .font(.customFont(fontFamily, style: .subheadline))
                    .foregroundColor(.accent)
                    .frame(width: iconWidth)

                VStack(alignment: .leading, spacing: tightestSpacing) {
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
