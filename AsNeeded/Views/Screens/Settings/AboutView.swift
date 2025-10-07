import SwiftUI
import SFSafeSymbols

struct AboutView: View {
	@ScaledMetric private var sectionSpacing: CGFloat = 24
	@ScaledMetric private var subsectionSpacing: CGFloat = 16
	@ScaledMetric private var groupSpacing: CGFloat = 12
	@ScaledMetric private var itemSpacing: CGFloat = 8
	@ScaledMetric private var mediumSpacing: CGFloat = 6
	@ScaledMetric private var tightSpacing: CGFloat = 4
	@ScaledMetric private var textSpacing: CGFloat = 2
	@ScaledMetric private var cardPadding: CGFloat = 16
	@ScaledMetric private var smallPadding: CGFloat = 4
	@ScaledMetric private var cornerRadius12: CGFloat = 12
	@ScaledMetric private var iconSize32: CGFloat = 32
	@Environment(\.fontFamily) private var fontFamily

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
  private var kevinWangURL: URL? { URL(string: "https://www.linkedin.com/in/kevinwywang/") }

  var body: some View {
	ScrollView {
	  VStack(alignment: .leading, spacing: sectionSpacing) {
		heroSection

		coreValuesSection

		developerAndSupportSection

		specialThanksSection

		technicalInfoSection

		appDependenciesSection

		testFlightSection
	  }
	  .padding(.horizontal)
	  .padding(.vertical)
	  .navigationTitle("About")
	}
  }

  private var heroSection: some View {
	VStack(alignment: .center, spacing: subsectionSpacing) {
	  VStack(spacing: itemSpacing) {
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
	.padding(.vertical, itemSpacing)
  }

  private var coreValuesSection: some View {
	VStack(alignment: .leading, spacing: subsectionSpacing) {
	  Text("Built on three core values")
		.font(.customFont(fontFamily, style: .title2, weight: .semibold))
		.frame(maxWidth: .infinity)

	  VStack(spacing: groupSpacing) {
		valueRow(icon: .lockShield, title: "Privacy First", description: "Your health data stays private, local, and secure")
		valueRow(icon: .giftFill, title: "Always Free", description: "All features free forever, no ads, no subscriptions required")
		valueRow(icon: .chevronLeftForwardslashChevronRight, title: "Open Source", description: "Transparent, inspectable, and community-driven")
	  }
	}
  }
  
  private var developerAndSupportSection: some View {
	VStack(alignment: .leading, spacing: subsectionSpacing) {
	  VStack(alignment: .leading, spacing: itemSpacing) {
		HStack(spacing: subsectionSpacing) {
		  if let url = mastodonURL {
			Link(destination: url) {
			  HStack(spacing: mediumSpacing) {
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
			  HStack(spacing: mediumSpacing) {
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
		.padding(.top, smallPadding)
	  }

	  NavigationLink {
		SupportView()
	  } label: {
		HStack(spacing: groupSpacing) {
		  Image(systemSymbol: .heart)
			.font(.title3)
			.foregroundColor(.red)

		  VStack(alignment: .leading, spacing: textSpacing) {
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
		.padding(cardPadding)
		.background(.regularMaterial)
		.cornerRadius(cornerRadius12)
	  }
	  .buttonStyle(.plain)
	}
  }
  
  private var specialThanksSection: some View {
	VStack(alignment: .leading, spacing: subsectionSpacing) {
	  Text("Special Thanks")
		.font(.customFont(fontFamily, style: .title2, weight: .semibold))

	  VStack(spacing: groupSpacing) {
		if let url = christineWangURL {
		  Link(destination: url) {
			HStack(spacing: subsectionSpacing) {
			  Image(systemSymbol: .starFill)
				.font(.title3.weight(.medium))
				.frame(width: iconSize32, height: iconSize32)
				.foregroundColor(.yellow)

			  VStack(alignment: .leading, spacing: tightSpacing) {
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
			.padding(cardPadding)
			.background(.regularMaterial)
			.cornerRadius(cornerRadius12)
		  }
		  .buttonStyle(.plain)
		} else {
		  HStack(spacing: subsectionSpacing) {
			Image(systemSymbol: .starFill)
			  .font(.title3.weight(.medium))
			  .frame(width: iconSize32, height: iconSize32)
			  .foregroundColor(.yellow)

			VStack(alignment: .leading, spacing: tightSpacing) {
			  Text("Christine Wang")
				.font(.headline)
				.fontWeight(.semibold)
			  Text("Design & Testing")
				.font(.subheadline)
				.foregroundColor(.secondary)
			}

			Spacer()
		  }
		  .padding(cardPadding)
		  .background(.regularMaterial)
		  .cornerRadius(cornerRadius12)
		}

		if let url = kevinWangURL {
		  Link(destination: url) {
			HStack(spacing: subsectionSpacing) {
			  Image(systemSymbol: .sparkles)
				.font(.title3.weight(.medium))
				.frame(width: iconSize32, height: iconSize32)
				.foregroundColor(.purple)

			  VStack(alignment: .leading, spacing: tightSpacing) {
				Text("Kevin Wang")
				  .font(.headline)
				  .fontWeight(.semibold)
				  .foregroundColor(.primary)
				Text("Vision & Details")
				  .font(.subheadline)
				  .foregroundColor(.secondary)
			  }

			  Spacer()

			  Image(systemSymbol: .arrowUpRightSquare)
				.font(.caption)
				.foregroundColor(.secondary)
			}
			.padding(cardPadding)
			.background(.regularMaterial)
			.cornerRadius(cornerRadius12)
		  }
		  .buttonStyle(.plain)
		}

		HStack(spacing: subsectionSpacing) {
		  Image(systemSymbol: .heartFill)
			.font(.title3.weight(.medium))
			.frame(width: iconSize32, height: iconSize32)
            .foregroundColor(.pink)

		  VStack(alignment: .leading, spacing: tightSpacing) {
			Text("My Wife, Jesse")
			  .font(.headline)
			  .fontWeight(.semibold)
			Text("Support & Encouragement")
			  .font(.subheadline)
			  .foregroundColor(.secondary)
		  }

		  Spacer()
		}
		.padding(cardPadding)
		.background(.regularMaterial)
		.cornerRadius(cornerRadius12)
	  }
	}
  }
  
  private var technicalInfoSection: some View {
	VStack(alignment: .leading, spacing: groupSpacing) {
	  Text("Technical Information")
		.font(.customFont(fontFamily, style: .title2, weight: .semibold))

	  VStack(spacing: itemSpacing) {
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
	.padding(cardPadding)
	.background(.regularMaterial)
	.cornerRadius(cornerRadius12)
  }

  private var appDependenciesSection: some View {
	NavigationLink {
	  AppDependenciesView()
	} label: {
	  HStack(spacing: groupSpacing) {
		Image(systemSymbol: .shippingboxFill)
		  .font(.title3)
		  .foregroundColor(.accent)

		VStack(alignment: .leading, spacing: textSpacing) {
		  Text("App Dependencies")
			.font(.headline)
			.fontWeight(.semibold)
			.foregroundColor(.primary)

		  Text("Third-party libraries used in this app")
			.font(.subheadline)
			.foregroundColor(.secondary)
		}

		Spacer()

		Image(systemSymbol: .chevronRight)
		  .font(.caption)
		  .foregroundColor(.secondary)
	  }
	  .padding(cardPadding)
	  .background(.regularMaterial)
	  .cornerRadius(cornerRadius12)
	}
	.buttonStyle(.plain)
  }

  private func valueRow(icon: SFSymbol, title: String, description: String) -> some View {
	HStack(spacing: subsectionSpacing) {
	  Image(systemSymbol: icon)
		.font(.title3.weight(.medium))
		.frame(width: iconSize32, height: iconSize32)
		.foregroundColor(.accentColor)

	  VStack(alignment: .leading, spacing: tightSpacing) {
		Text(title)
		  .font(.headline)
		  .fontWeight(.semibold)
		Text(description)
		  .font(.subheadline)
		  .foregroundColor(.secondary)
	  }

	  Spacer()
	}
	.padding(cardPadding)
	.background(.regularMaterial)
	.cornerRadius(cornerRadius12)
  }

  private var testFlightSection: some View {
	VStack(alignment: .leading, spacing: subsectionSpacing) {
	  Text("Join the Beta")
		.font(.customFont(fontFamily, style: .title2, weight: .semibold))

	  TestFlightAccessComponent()
	}
  }
}

#if DEBUG
#Preview {
  NavigationView { AboutView() }
}
#endif
