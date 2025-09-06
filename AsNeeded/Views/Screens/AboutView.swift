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
	  VStack(alignment: .leading, spacing: 24) {
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
	VStack(alignment: .center, spacing: 16) {
	  VStack(spacing: 8) {
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
	.padding(.vertical, 8)
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
  
  private var developerAndSupportSection: some View {
	VStack(alignment: .leading, spacing: 16) {
	  VStack(alignment: .leading, spacing: 8) {
		Text("Built by Contributors")
		  .font(.title2)
		  .fontWeight(.semibold)
		
		Text("An open source project by developers passionate about privacy-focused healthcare. We believe technology should serve people, not exploit them.")
		  .font(.body)
		  .foregroundStyle(.secondary)
		
		HStack(spacing: 16) {
		  if let url = mastodonURL {
			Link(destination: url) {
			  HStack(spacing: 6) {
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
			  HStack(spacing: 6) {
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
		.padding(.top, 4)
	  }
	  
	  NavigationLink {
		SupportView()
	  } label: {
		HStack(spacing: 12) {
		  Image(systemSymbol: .heart)
			.font(.title3)
			.foregroundColor(.red)
		  
		  VStack(alignment: .leading, spacing: 2) {
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
		.padding(16)
		.background(.regularMaterial)
		.cornerRadius(12)
	  }
	  .buttonStyle(.plain)
	}
  }
  
  private var specialThanksSection: some View {
	VStack(alignment: .leading, spacing: 16) {
	  Text("Special Thanks")
		.font(.title2)
		.fontWeight(.semibold)
	  
	  VStack(spacing: 12) {
		HStack(spacing: 16) {
		  Image(systemSymbol: .starFill)
			.font(.system(size: 20, weight: .medium))
			.frame(width: 32, height: 32)
            .foregroundColor(.yellow)
		  
		  VStack(alignment: .leading, spacing: 4) {
			Text("Christine Wang")
			  .font(.headline)
			  .fontWeight(.semibold)
			Text("Design & Testing")
			  .font(.subheadline)
			  .foregroundColor(.secondary)
		  }
		  
		  Spacer()
		}
		.padding(16)
		.background(.regularMaterial)
		.cornerRadius(12)
		
		HStack(spacing: 16) {
		  Image(systemSymbol: .heartFill)
			.font(.system(size: 20, weight: .medium))
			.frame(width: 32, height: 32)
            .foregroundColor(.pink)
		  
		  VStack(alignment: .leading, spacing: 4) {
			Text("Jesse")
			  .font(.headline)
			  .fontWeight(.semibold)
			Text("Support & Encouragement")
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
  }
  
  private var technicalInfoSection: some View {
	VStack(alignment: .leading, spacing: 12) {
	  Text("Technical Information")
		.font(.title2)
		.fontWeight(.semibold)
	  
	  VStack(spacing: 8) {
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
	.padding(16)
	.background(.regularMaterial)
	.cornerRadius(12)
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
  NavigationView { AboutView() }
}
#endif
