import SFSafeSymbols
import SwiftUI

struct NIHDisclaimerDetailView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let mainSpacing: CGFloat = 24
	private let sectionSpacing: CGFloat = 16
	private let itemSpacing: CGFloat = 12
	private let smallSpacing: CGFloat = 8
	private let tinySpacing: CGFloat = 6
	private let tightSpacing: CGFloat = 4
	private let padding: CGFloat = 16
	private let cornerRadius: CGFloat = 12

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: mainSpacing) {
                // Main Attribution
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    HStack(spacing: itemSpacing) {
                        Image(systemSymbol: .buildingColumnsFill)
                            .foregroundStyle(.blue)
                            .font(.customFont(fontFamily, style: .title))

                        Text("Medical Data Sources")
                            .font(.customFont(fontFamily, style: .title2))
                            .fontWeight(.bold)
                    }

                    Text("All medication information is sourced from official U.S. government databases:")
                        .font(.customFont(fontFamily, style: .body))
                        .multilineTextAlignment(.leading)

                    VStack(alignment: .leading, spacing: smallSpacing) {
                        Text("• U.S. National Library of Medicine (NLM)")
                            .font(.customFont(fontFamily, style: .body))
                            .fontWeight(.medium)
                        Text("• National Institutes of Health")
                            .font(.customFont(fontFamily, style: .body))
                            .fontWeight(.medium)
                        Text("• Department of Health and Human Services")
                            .font(.customFont(fontFamily, style: .body))
                            .fontWeight(.medium)
                    }

                    Button(action: {
                        if let url = URL(string: "https://www.nlm.nih.gov/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: tightSpacing) {
                            Text("Visit the National Library of Medicine")
                                .font(.customFont(fontFamily, style: .caption))
                                .foregroundStyle(.accent)
                                .underline()
                            Image(systemSymbol: .arrowUpRightSquare)
                                .font(.customFont(fontFamily, style: .caption2))
                                .foregroundStyle(.accent)
                        }
                    }
                    .buttonStyle(.plain)

                    Text("NLM is not responsible for the product and does not endorse or recommend this or any other product.")
                        .font(.customFont(fontFamily, style: .body))
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
                        .font(.customFont(fontFamily, style: .title2))
                        .fontWeight(.bold)

                    Text("It is not the intention of NLM to provide specific medical advice, but rather to provide users with information to better understand their health and their medications.")
                        .font(.customFont(fontFamily, style: .body))
                        .multilineTextAlignment(.leading)

                    Text("NLM urges you to consult with a qualified physician for advice about medications.")
                        .font(.customFont(fontFamily, style: .body))
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                }

                // About RxNorm
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    Text("RxNorm Database Citation")
                        .font(.customFont(fontFamily, style: .title2))
                        .fontWeight(.bold)

                    Text("This app uses the RxNorm database, an authoritative medication terminology system maintained by the National Library of Medicine.")
                        .font(.customFont(fontFamily, style: .body))
                        .multilineTextAlignment(.leading)

                    Text("RxNorm provides:")
                        .font(.customFont(fontFamily, style: .body))

                    VStack(alignment: .leading, spacing: smallSpacing) {
                        Label("Medication search functionality", systemSymbol: .magnifyingglass)
                            .font(.customFont(fontFamily, style: .body))

                        Label("Standardized medication names", systemSymbol: .textBadgePlus)
                            .font(.customFont(fontFamily, style: .body))

                        Label("Drug information and relationships", systemSymbol: .linkCircle)
                            .font(.customFont(fontFamily, style: .body))
                    }

                    VStack(alignment: .leading, spacing: tinySpacing) {
                        Text("Official Sources:")
                            .font(.customFont(fontFamily, style: .body))
                            .fontWeight(.medium)

                        Button(action: {
                            if let url = URL(string: "https://www.nlm.nih.gov/research/umls/rxnorm/") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: tightSpacing) {
                                Text("RxNorm Database Homepage")
                                    .font(.customFont(fontFamily, style: .caption))
                                    .foregroundStyle(.accent)
                                    .underline()
                                Image(systemSymbol: .arrowUpRightSquare)
                                    .font(.customFont(fontFamily, style: .caption2))
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
                                    .font(.customFont(fontFamily, style: .caption))
                                    .foregroundStyle(.accent)
                                    .underline()
                                Image(systemSymbol: .arrowUpRightSquare)
                                    .font(.customFont(fontFamily, style: .caption2))
                                    .foregroundStyle(.accent)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Text("The RxNorm data is updated monthly by NLM and provides standardized names for clinical drugs and links its names to many of the drug vocabularies commonly used in pharmacy management and drug interaction software.")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(padding)
        }
        .customNavigationTitle("Data Attribution", displayMode: .large)
    }
}

#if DEBUG
    #Preview {
        NavigationView {
            NIHDisclaimerDetailView()
        }
    }
#endif
