import SwiftUI
import SFSafeSymbols

struct AboutView: View {
  private var appName: String {
	Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
	?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
	?? "AsNeeded"
  }
  private var version: String {
	Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
  }
  private var build: String {
	Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
  }
  private var githubURL: URL? { URL(string: "https://github.com/dan-hart/AsNeeded") }
  private var githubProfileURL: URL? { URL(string: "https://github.com/dan-hart") }
  private var mastodonURL: URL? { URL(string: "https://mas.to/@codedbydan") }

  var body: some View {
	ScrollView {
	  VStack(alignment: .leading, spacing: 20) {
		headerSection

		Divider()

		appInfoSection

		Divider()

		aboutDescriptionSection

		Divider()

		coreValuesSection

		Divider()

		developerSection

		Divider()

		supportSection
	  }
	  .padding()
	  .navigationTitle("About")
	}
  }

  private var headerSection: some View {
	VStack(alignment: .leading, spacing: 8) {
	  Text(appName)
		.font(.largeTitle)
		.fontWeight(.semibold)
	  Text("Version \(version) (\(build))")
		.foregroundStyle(.secondary)
		.font(.subheadline)
	}
  }

  private var appInfoSection: some View {
	VStack(alignment: .leading, spacing: 12) {
	  Text("App Information")
		.font(.headline)
		.fontWeight(.semibold)

	  VStack(spacing: 12) {
		if let url = githubURL {
		  linkRow(title: "Source Code",
				  subtitle: "github.com/dan-hart/AsNeeded",
				  systemImage: .chevronLeftForwardslashChevronRight,
				  url: url)
		}
		infoRow(title: "Version", value: version, systemImage: .number)
		infoRow(title: "Build", value: build, systemImage: .wrenchAndScrewdriver)
	  }
	}
  }

  private var aboutDescriptionSection: some View {
	VStack(alignment: .leading, spacing: 12) {
	  Text("About This App")
		.font(.headline)
		.fontWeight(.semibold)
	  Text("AsNeeded helps you track medications taken on an as-needed basis. It focuses on clear logging, trends, and data portability.")
		.font(.body)
		.foregroundStyle(.secondary)
	  
	  VStack(alignment: .leading, spacing: 8) {
		Text("🆓 Always Free & Open Source")
		  .font(.subheadline)
		  .fontWeight(.medium)
		  .foregroundColor(.green)
		
		Text("This app will always be completely free with no advertisements, subscriptions, or premium features. The source code is open and available for anyone to inspect, modify, or contribute to.")
		  .font(.caption)
		  .foregroundStyle(.secondary)
	  }
	  .padding(12)
	  .background(Color.green.opacity(0.1))
	  .cornerRadius(8)
	}
  }

  private var coreValuesSection: some View {
	VStack(alignment: .leading, spacing: 12) {
	  Text("Core Values")
		.font(.headline)
		.fontWeight(.semibold)
	  
	  VStack(alignment: .leading, spacing: 8) {
		valueRow(icon: .wifiSlash, title: "Offline-first", description: "Works without internet connection")
		valueRow(icon: .externaldrive, title: "Local data only", description: "Your data stays on your device")
		valueRow(icon: .lock, title: "Privacy is a human right", description: "No tracking, no analytics, no data collection")
		valueRow(icon: .textPageBadgeMagnifyingglass, title: "Open & inspectable", description: "Source code available on GitHub")
		valueRow(icon: .dollarsignCircle, title: "Free & modifiable", description: "All features free, forever")
	  }
	}
  }

  private var developerSection: some View {
	VStack(alignment: .leading, spacing: 12) {
	  Text("Developer")
		.font(.headline)
		.fontWeight(.semibold)
	  
	  Text("Hi! I'm Dan Hart, an iOS developer passionate about privacy-focused healthcare apps. I believe technology should serve people, not exploit them.")
		.font(.body)
		.foregroundStyle(.secondary)
	  
	  VStack(spacing: 12) {
		if let url = mastodonURL {
		  linkRow(title: "Mastodon",
				  subtitle: "@codedbydan@mas.to",
				  systemImage: .atCircle,
				  url: url)
		}
		if let url = githubProfileURL {
		  linkRow(title: "GitHub",
				  subtitle: "github.com/dan-hart",
				  systemImage: .chevronLeftForwardslashChevronRight,
				  url: url)
		}
	  }
	}
  }

  private var supportSection: some View {
	VStack(alignment: .leading, spacing: 12) {
	  Text("Support Development")
		.font(.headline)
		.fontWeight(.semibold)
	  
	  Text("If As Needed helps you manage your medications, consider supporting its continued development and maintenance.")
		.font(.body)
		.foregroundStyle(.secondary)
	  
	  NavigationLink {
		SupportView()
	  } label: {
		HStack(spacing: 12) {
		  Image(systemSymbol: .heart)
			.font(.system(size: 18, weight: .medium))
			.frame(width: 24, height: 24)
			.foregroundColor(.red)
		  VStack(alignment: .leading, spacing: 2) {
			Text("Support As Needed")
			  .font(.body)
			  .fontWeight(.medium)
			Text("Ways to support this free app")
			  .font(.caption)
			  .foregroundColor(.secondary)
		  }
		  Spacer()
		  Image(systemSymbol: .chevronRight)
			.font(.caption)
			.foregroundColor(.secondary)
		}
		.padding(16)
		.background(Color(.systemBackground))
		.overlay(
		  RoundedRectangle(cornerRadius: 12)
			.stroke(Color(.systemGray4), lineWidth: 0.5)
		)
		.cornerRadius(12)
	  }
	  .buttonStyle(.plain)
	}
  }

  private func valueRow(icon: SFSymbol, title: String, description: String) -> some View {
	HStack(spacing: 12) {
	  Image(systemSymbol: icon)
		.font(.system(size: 16, weight: .medium))
		.frame(width: 20, height: 20)
		.foregroundColor(.blue)
	  
	  VStack(alignment: .leading, spacing: 2) {
		Text(title)
		  .font(.body)
		  .fontWeight(.medium)
		Text(description)
		  .font(.caption)
		  .foregroundColor(.secondary)
	  }
	  
	  Spacer()
	}
  }

  private func infoRow(title: String, value: String, systemImage: SFSymbol) -> some View {
	HStack(spacing: 12) {
	  Image(systemSymbol: systemImage)
		.font(.system(size: 18, weight: .medium))
		.frame(width: 24, height: 24)
		.foregroundColor(.blue)
	  VStack(alignment: .leading, spacing: 2) {
		Text(title)
		  .font(.subheadline)
		  .foregroundStyle(.secondary)
		Text(value)
		  .font(.body)
		  .fontWeight(.medium)
	  }
	  Spacer()
	}
	.padding(16)
	.background(Color(.systemBackground))
	.overlay(
	  RoundedRectangle(cornerRadius: 12)
		.stroke(Color(.systemGray4), lineWidth: 0.5)
	)
	.cornerRadius(12)
  }

  private func linkRow(title: String, subtitle: String, systemImage: SFSymbol, url: URL) -> some View {
	Link(destination: url) {
	  HStack(spacing: 12) {
		Image(systemSymbol: systemImage)
		  .font(.system(size: 18, weight: .medium))
		  .frame(width: 24, height: 24)
		  .foregroundColor(.blue)
		VStack(alignment: .leading, spacing: 2) {
		  Text(title)
			.font(.body)
			.fontWeight(.medium)
		  Text(subtitle)
			.font(.caption)
			.foregroundColor(.secondary)
		}
		Spacer()
		Image(systemSymbol: .arrowUpRightSquare)
		  .font(.caption)
		  .foregroundColor(.secondary)
	  }
	  .padding(16)
	  .background(Color(.systemBackground))
	  .overlay(
		RoundedRectangle(cornerRadius: 12)
		  .stroke(Color(.systemGray4), lineWidth: 0.5)
	  )
	  .cornerRadius(12)
	}
	.buttonStyle(.plain)
  }
}

#if DEBUG
#Preview {
  NavigationView { AboutView() }
}
#endif
