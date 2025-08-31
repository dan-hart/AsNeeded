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

  var body: some View {
	ScrollView {
	  VStack(alignment: .leading, spacing: 20) {
		headerSection

		Divider()

		appInfoSection

		Divider()

		aboutDescriptionSection
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
		  linkRow(title: "GitHub",
				  subtitle: "github.com/dan-hart/AsNeeded",
				  systemImage: .link,
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
