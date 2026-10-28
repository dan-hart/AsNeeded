import SFSafeSymbols
import SwiftUI

struct NIHDisclaimerView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let mainSpacing: CGFloat = 12
	private let itemSpacing: CGFloat = 12
	private let smallSpacing: CGFloat = 8
	private let tinySpacing: CGFloat = 4
	private let padding: CGFloat = 16
	private let cornerRadius: CGFloat = 12

    @State private var showFullDisclaimer = false

    var body: some View {
        VStack(alignment: .leading, spacing: mainSpacing) {
            HStack(alignment: .top, spacing: itemSpacing) {
                Image(systemSymbol: .infoCircleFill)
                    .foregroundStyle(.blue.opacity(0.8))
                    .font(.customFont(fontFamily, style: .title2))

                VStack(alignment: .leading, spacing: smallSpacing) {
                    Text("Medical Data Source")
                        .font(.customFont(fontFamily, style: .headline))

                    Text("Medication information provided by:")
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundStyle(.secondary)

                    Text("U.S. National Library of Medicine (NLM)\nNational Institutes of Health")
                        .font(.customFont(fontFamily, style: .subheadline))
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Button {
                        showFullDisclaimer = true
                    } label: {
                        Text("View full disclaimer")
                            .font(.customFont(fontFamily, style: .body))
                            .fontWeight(.medium)
                    }
                    .padding(.top, tinySpacing)
                }
            }
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
	@Environment(\.fontFamily) private var fontFamily
	private let mainSpacing: CGFloat = 24
	private let sectionSpacing: CGFloat = 16
	private let smallSpacing: CGFloat = 8
	private let tinySpacing: CGFloat = 4
	private let padding: CGFloat = 16
	private let cornerRadius: CGFloat = 12

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VerticalOnlyScrollView {
                VStack(alignment: .leading, spacing: mainSpacing) {
                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        Text("Medical Information Sources")
                            .font(.customFont(fontFamily, style: .title2))
                            .fontWeight(.bold)

                        Text("All medication information in this app is sourced from:")
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
                            HStack(spacing: tinySpacing) {
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
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        Text("Medical Information Disclaimer")
                            .font(.customFont(fontFamily, style: .title2))
                            .fontWeight(.bold)

                        Text("It is not the intention of NLM to provide specific medical advice, but rather to provide users with information to better understand their health and their medications. NLM urges you to consult with a qualified physician for advice about medications.")
                            .font(.customFont(fontFamily, style: .body))
                            .multilineTextAlignment(.leading)
                    }

                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        Text("About RxNorm Database")
                            .font(.customFont(fontFamily, style: .title2))
                            .fontWeight(.bold)

                        Text("This app uses the RxNorm database and API, a comprehensive medication terminology system:")
                            .font(.customFont(fontFamily, style: .body))
                            .multilineTextAlignment(.leading)

                        VStack(alignment: .leading, spacing: smallSpacing) {
                            Text("• Developed and maintained by NLM")
                                .font(.customFont(fontFamily, style: .body))
                            Text("• Contains standardized medication names")
                                .font(.customFont(fontFamily, style: .body))
                            Text("• Updated monthly with latest drug information")
                                .font(.customFont(fontFamily, style: .body))
                            Text("• Used by healthcare systems worldwide")
                                .font(.customFont(fontFamily, style: .body))
                        }

                        Button(action: {
                            if let url = URL(string: "https://lhncbc.nlm.nih.gov/RxNav/") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: tinySpacing) {
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

                        Button(action: {
                            if let url = URL(string: "https://www.nlm.nih.gov/research/umls/rxnorm/") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: tinySpacing) {
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
                    }
                }
                .padding(padding)
            }
            .customNavigationTitle("NIH Data Attribution", displayMode: .large)
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
            .tint(.accent)
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
