import SwiftUI
import SFSafeSymbols

struct WelcomeView: View {
	@ScaledMetric private var spacing24: CGFloat = 24
	@ScaledMetric private var spacing16: CGFloat = 16
	@ScaledMetric private var spacing12: CGFloat = 12
	@ScaledMetric private var spacing8: CGFloat = 8
	@ScaledMetric private var spacing4: CGFloat = 4
	@ScaledMetric private var padding16: CGFloat = 16
	@ScaledMetric private var padding8: CGFloat = 8
	@ScaledMetric private var cornerRadius12: CGFloat = 12
	@ScaledMetric private var iconSize32: CGFloat = 32

  @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
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
	  VStack(alignment: .leading, spacing: spacing24) {
		welcomeSection

		coreValuesSection

		continueSection
	  }
	  .padding(.horizontal)
	  .padding(.vertical)
	}
	.navigationBarHidden(true)
  }

  private var welcomeSection: some View {
	VStack(alignment: .center, spacing: spacing16) {
	  VStack(spacing: spacing8) {
		Text("Welcome to")
		  .font(.title2)
		  .foregroundStyle(.secondary)

		Text(appName)
		  .font(.largeTitle)
		  .fontWeight(.bold)
		  .multilineTextAlignment(.center)

		Text("Track as-needed medications with privacy and simplicity")
		  .font(.title3)
		  .foregroundStyle(.secondary)
		  .multilineTextAlignment(.center)
	  }
	}
	.frame(maxWidth: .infinity)
	.padding(.vertical, padding16)
  }

  private var coreValuesSection: some View {
	VStack(alignment: .leading, spacing: spacing16) {
	  Text("Built on three core values")
		.font(.title2)
		.fontWeight(.semibold)
		.frame(maxWidth: .infinity)

	  VStack(spacing: spacing12) {
		valueRow(icon: .lockShield, title: "Privacy First", description: "Your health data stays private, local, and secure")
		valueRow(icon: .giftFill, title: "Always Free", description: "All features free forever, no ads, no subscriptions required")
		valueRow(icon: .chevronLeftForwardslashChevronRight, title: "Open Source", description: "Transparent, inspectable, and community-driven")
	  }
	}
  }
  
  private var continueSection: some View {
	VStack(spacing: spacing16) {
	  medicalDisclaimer

	  Button {
		hasSeenWelcome = true
		dismiss()
	  } label: {
		HStack {
		  Spacer()
		  Text("Continue")
			.font(.headline)
			.fontWeight(.semibold)
			.foregroundColor(.white)
		  Spacer()
		}
		.padding(.vertical, padding16)
		.background(Color.accentColor)
		.cornerRadius(cornerRadius12)
	  }
	  .buttonStyle(.plain)

	  Text("Version \(version)")
		.font(.caption)
		.foregroundStyle(.tertiary)
		.frame(maxWidth: .infinity)
	}
	.padding(.top, padding8)
  }
  
  private var medicalDisclaimer: some View {
      VStack {
          Text("Medical Disclaimer")
            .font(.title2)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
          
          MedicalDisclaimerView()
      }
  }

  private func valueRow(icon: SFSymbol, title: String, description: String) -> some View {
	HStack(spacing: spacing16) {
	  Image(systemSymbol: icon)
		.font(.system(.title3, design: .default, weight: .medium))
		.frame(width: iconSize32, height: iconSize32)
		.foregroundColor(.accentColor)

	  VStack(alignment: .leading, spacing: spacing4) {
		Text(title)
		  .font(.headline)
		  .fontWeight(.semibold)
		Text(description)
		  .font(.subheadline)
		  .foregroundColor(.secondary)
	  }

	  Spacer()
	}
	.padding(padding16)
	.background(.regularMaterial)
	.cornerRadius(cornerRadius12)
  }
}

#if DEBUG
#Preview {
  WelcomeView()
}
#endif
