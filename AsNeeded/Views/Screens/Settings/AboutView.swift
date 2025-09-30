import SwiftUI
import SFSafeSymbols

struct AboutView: View {
	@ScaledMetric private var spacing24: CGFloat = 24
	@ScaledMetric private var spacing16: CGFloat = 16
	@ScaledMetric private var spacing12: CGFloat = 12
	@ScaledMetric private var spacing8: CGFloat = 8
	@ScaledMetric private var spacing6: CGFloat = 6
	@ScaledMetric private var spacing4: CGFloat = 4
	@ScaledMetric private var spacing2: CGFloat = 2
	@ScaledMetric private var padding16: CGFloat = 16
	@ScaledMetric private var padding4: CGFloat = 4
	@ScaledMetric private var cornerRadius12: CGFloat = 12
	@ScaledMetric private var iconSize32: CGFloat = 32

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
  private var christineWangURL: URL? { URL(string: "https://christinewang.design/") }

  var body: some View {
	ScrollView {
	  VStack(alignment: .leading, spacing: spacing24) {
		heroSection

		coreValuesSection

		developerAndSupportSection

		specialThanksSection

		technicalInfoSection
	  }
	  .padding(.horizontal)
	  .padding(.vertical)
	  .navigationTitle("About")
	}
  }

  private var heroSection: some View {
	VStack(alignment: .center, spacing: spacing16) {
	  VStack(spacing: spacing8) {
		Text(appName)
		  .font(.largeTitle)
		  .fontWeight(.bold)
		  .multilineTextAlignment(.center)

		Text("Track as-needed medications with privacy and simplicity")
		  .font(.title3)
		  .foregroundStyle(.secondary)
		  .multilineTextAlignment(.center)

		Text("Version \(version)")
		  .font(.caption)
		  .foregroundStyle(.tertiary)
	  }
	}
	.frame(maxWidth: .infinity)
	.padding(.vertical, spacing8)
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
  
  private var developerAndSupportSection: some View {
	VStack(alignment: .leading, spacing: spacing16) {
	  VStack(alignment: .leading, spacing: spacing8) {
		HStack(spacing: spacing16) {
		  if let url = mastodonURL {
			Link(destination: url) {
			  HStack(spacing: spacing6) {
				Image(systemSymbol: .atCircle)
				  .font(.subheadline)
				Text("Dan Hart on Mastodon")
				  .font(.subheadline)
				  .fontWeight(.medium)
			  }
			  .foregroundStyle(Color.accentColor)
			}
		  }

		  if let url = githubProfileURL {
			Link(destination: url) {
			  HStack(spacing: spacing6) {
				Image(systemSymbol: .chevronLeftForwardslashChevronRight)
				  .font(.subheadline)
				Text("Dan Hart on GitHub")
				  .font(.subheadline)
				  .fontWeight(.medium)
			  }
			  .foregroundStyle(Color.accentColor)
			}
		  }
		}
		.padding(.top, padding4)
	  }

	  NavigationLink {
		SupportView()
	  } label: {
		HStack(spacing: spacing12) {
		  Image(systemSymbol: .heart)
			.font(.title3)
			.foregroundColor(.red)

		  VStack(alignment: .leading, spacing: spacing2) {
			Text("Support As Needed")
			  .font(.headline)
			  .fontWeight(.semibold)
			  .foregroundColor(.primary)

			Text("Help keep this app free and open source")
			  .font(.subheadline)
			  .foregroundColor(.secondary)
		  }

		  Spacer()

		  Image(systemSymbol: .chevronRight)
			.font(.caption)
			.foregroundColor(.secondary)
		}
		.padding(padding16)
		.background(.regularMaterial)
		.cornerRadius(cornerRadius12)
	  }
	  .buttonStyle(.plain)
	}
  }
  
  private var specialThanksSection: some View {
	VStack(alignment: .leading, spacing: spacing16) {
	  Text("Special Thanks")
		.font(.title2)
		.fontWeight(.semibold)

	  VStack(spacing: spacing12) {
		if let url = christineWangURL {
		  Link(destination: url) {
			HStack(spacing: spacing16) {
			  Image(systemSymbol: .starFill)
				.font(.system(.title3, design: .default, weight: .medium))
				.frame(width: iconSize32, height: iconSize32)
				.foregroundColor(.yellow)

			  VStack(alignment: .leading, spacing: spacing4) {
				Text("Christine Wang")
				  .font(.headline)
				  .fontWeight(.semibold)
				  .foregroundColor(.primary)
				Text("Design & Testing")
				  .font(.subheadline)
				  .foregroundColor(.secondary)
			  }

			  Spacer()

			  Image(systemSymbol: .arrowUpRightSquare)
				.font(.caption)
				.foregroundColor(.secondary)
			}
			.padding(padding16)
			.background(.regularMaterial)
			.cornerRadius(cornerRadius12)
		  }
		  .buttonStyle(.plain)
		} else {
		  HStack(spacing: spacing16) {
			Image(systemSymbol: .starFill)
			  .font(.system(.title3, design: .default, weight: .medium))
			  .frame(width: iconSize32, height: iconSize32)
			  .foregroundColor(.yellow)

			VStack(alignment: .leading, spacing: spacing4) {
			  Text("Christine Wang")
				.font(.headline)
				.fontWeight(.semibold)
			  Text("Design & Testing")
				.font(.subheadline)
				.foregroundColor(.secondary)
			}

			Spacer()
		  }
		  .padding(padding16)
		  .background(.regularMaterial)
		  .cornerRadius(cornerRadius12)
		}

		HStack(spacing: spacing16) {
		  Image(systemSymbol: .heartFill)
			.font(.system(.title3, design: .default, weight: .medium))
			.frame(width: iconSize32, height: iconSize32)
            .foregroundColor(.pink)

		  VStack(alignment: .leading, spacing: spacing4) {
			Text("My Wife, Jesse")
			  .font(.headline)
			  .fontWeight(.semibold)
			Text("Support & Encouragement")
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
  }
  
  private var technicalInfoSection: some View {
	VStack(alignment: .leading, spacing: spacing12) {
	  Text("Technical Information")
		.font(.title2)
		.fontWeight(.semibold)

	  VStack(spacing: spacing8) {
		HStack {
		  Text("Version")
			.foregroundStyle(.secondary)
		  Spacer()
		  Text(version)
			.fontWeight(.medium)
		}

		HStack {
		  Text("Build")
			.foregroundStyle(.secondary)
		  Spacer()
		  Text(build)
			.fontWeight(.medium)
		}

		if let url = githubURL {
		  HStack {
			Text("Source Code")
			  .foregroundStyle(.secondary)
			Spacer()
			Link("GitHub", destination: url)
			  .fontWeight(.medium)
			  .foregroundStyle(Color.accentColor)
		  }
		}
	  }
	}
	.padding(padding16)
	.background(.regularMaterial)
	.cornerRadius(cornerRadius12)
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
  NavigationView { AboutView() }
}
#endif
