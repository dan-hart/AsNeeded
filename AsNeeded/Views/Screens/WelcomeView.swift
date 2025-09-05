import SwiftUI
import SFSafeSymbols

struct WelcomeView: View {
  @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
  @Environment(\.dismiss) private var dismiss
  
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
	  VStack(alignment: .leading, spacing: 24) {
		welcomeSection
		
		coreValuesSection
		
		developerSection
		
		continueSection
	  }
	  .padding(.horizontal)
	  .padding(.vertical)
	}
	.navigationBarHidden(true)
  }

  private var welcomeSection: some View {
	VStack(alignment: .center, spacing: 16) {
	  VStack(spacing: 8) {
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
	.padding(.vertical, 16)
  }

  private var coreValuesSection: some View {
	VStack(alignment: .leading, spacing: 16) {
	  Text("Built on three core values")
		.font(.title2)
		.fontWeight(.semibold)
		.frame(maxWidth: .infinity)
	  
	  VStack(spacing: 12) {
		valueRow(icon: .lockShield, title: "Privacy First", description: "Your health data stays private, local, and secure")
		valueRow(icon: .giftFill, title: "Always Free", description: "All features free forever, no ads, no subscriptions required")
		valueRow(icon: .chevronLeftForwardslashChevronRight, title: "Open Source", description: "Transparent, inspectable, and community-driven")
	  }
	}
  }
  
  private var developerSection: some View {
	VStack(alignment: .leading, spacing: 12) {
	  Text("Built by Contributors")
		.font(.title2)
		.fontWeight(.semibold)
	  
	  Text("An open source project by developers passionate about privacy-focused healthcare. We believe technology should serve people, not exploit them.")
		.font(.body)
		.foregroundStyle(.secondary)
	}
  }
  
  private var continueSection: some View {
	VStack(spacing: 16) {
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
		.padding(.vertical, 16)
		.background(Color.accentColor)
		.cornerRadius(12)
	  }
	  .buttonStyle(.plain)
	  
	  Text("Version \(version)")
		.font(.caption)
		.foregroundStyle(.tertiary)
		.frame(maxWidth: .infinity)
	}
	.padding(.top, 8)
  }

  private func valueRow(icon: SFSymbol, title: String, description: String) -> some View {
	HStack(spacing: 16) {
	  Image(systemSymbol: icon)
		.font(.system(size: 20, weight: .medium))
		.frame(width: 32, height: 32)
		.foregroundColor(.accentColor)
	  
	  VStack(alignment: .leading, spacing: 4) {
		Text(title)
		  .font(.headline)
		  .fontWeight(.semibold)
		Text(description)
		  .font(.subheadline)
		  .foregroundColor(.secondary)
	  }
	  
	  Spacer()
	}
	.padding(16)
	.background(.regularMaterial)
	.cornerRadius(12)
  }
}

#if DEBUG
#Preview {
  WelcomeView()
}
#endif