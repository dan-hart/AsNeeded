import SFSafeSymbols
import SwiftUI

struct WelcomeView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let sectionSpacing: CGFloat = 24
	private let subsectionSpacing: CGFloat = 16
	private let itemSpacing: CGFloat = 12
	private let textSpacing: CGFloat = 8
	private let tightSpacing: CGFloat = 4
	private let standardPadding: CGFloat = 16
	private let smallPadding: CGFloat = 8
	private let cornerRadius12: CGFloat = 12
	private let iconSize32: CGFloat = 32

    @AppStorage(UserDefaultsKeys.hasSeenWelcome) private var hasSeenWelcome: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var showMedicalDisclaimer = false

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "AsNeeded"
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                welcomeSection

                coreValuesSection

                medicalDisclaimer
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom) {
            continueSection
                .padding(.horizontal)
                .padding(.bottom, smallPadding)
                .background(.regularMaterial)
        }
    }

    private var welcomeSection: some View {
        VStack(alignment: .center, spacing: subsectionSpacing) {
            VStack(spacing: textSpacing) {
                Text("Welcome to")
                    .font(.customFont(fontFamily, style: .title2))
                    .foregroundStyle(.secondary)

                Text(appName)
                    .font(.customFont(fontFamily, style: .largeTitle))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Track as-needed medications with privacy and simplicity")
                    .font(.customFont(fontFamily, style: .title3))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, standardPadding)
    }

    private var coreValuesSection: some View {
        VStack(alignment: .leading, spacing: subsectionSpacing) {
            Text("Built on three core values")
                .font(.customFont(fontFamily, style: .title2))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)

            VStack(spacing: itemSpacing) {
                valueRow(icon: .lockShield, title: "Privacy First", description: "Your health data stays private, local, and secure")
                valueRow(icon: .giftFill, title: "Always Free", description: "All features free forever, no ads, no subscriptions required")
                valueRow(icon: .chevronLeftForwardslashChevronRight, title: "Open Source", description: "Transparent, inspectable, and community-driven")
            }
        }
    }

    private var continueSection: some View {
        VStack(spacing: subsectionSpacing) {
            Button {
                hasSeenWelcome = true
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("Continue")
                        .font(.customFont(fontFamily, style: .headline))
                        .fontWeight(.semibold)
                        .filledButtonForeground(against: .accent)
                    Spacer()
                }
                .padding(.vertical, standardPadding)
                .background(Color.accent.dynamicFilledButtonBackground)
                .cornerRadius(cornerRadius12)
            }
            .buttonStyle(.plain)

            Text("Version \(version)")
                .font(.customFont(fontFamily, style: .caption))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, smallPadding)
    }

    private var medicalDisclaimer: some View {
        VStack {
            Text("Medical Disclaimer")
                .font(.customFont(fontFamily, style: .title2))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)

            MedicalDisclaimerView()
        }
    }

    private func valueRow(icon: SFSymbol, title: String, description: String) -> some View {
        HStack(spacing: subsectionSpacing) {
            Image(systemSymbol: icon)
                .font(.title3.weight(.medium))
                .frame(width: iconSize32, height: iconSize32)
                .foregroundColor(.accent)

            VStack(alignment: .leading, spacing: tightSpacing) {
                Text(title)
                    .font(.customFont(fontFamily, style: .headline))
                    .fontWeight(.semibold)
                Text(description)
                    .font(.customFont(fontFamily, style: .subheadline))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(standardPadding)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    // Specular highlight for premium glass effect
                    RoundedRectangle(cornerRadius: cornerRadius12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .clear,
                                    .white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                )
        }
    }
}

#if DEBUG
    #Preview {
        WelcomeView()
    }
#endif
