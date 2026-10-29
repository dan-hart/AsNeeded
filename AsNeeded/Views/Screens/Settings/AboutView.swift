import SFSafeSymbols
import SwiftUI

struct AboutView: View {
	private let sectionSpacing: CGFloat = 24
	private let subsectionSpacing: CGFloat = 16
	private let groupSpacing: CGFloat = 12
	private let itemSpacing: CGFloat = 8
	private let tightSpacing: CGFloat = 4
	private let textSpacing: CGFloat = 2
	private let cardPadding: CGFloat = 16
	private let cornerRadius12: CGFloat = 12
	private let iconSize32: CGFloat = 32
    @Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        VerticalOnlyScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                heroSection

                coreValuesSection

                supportSection

                specialThanksSection

                developerSection

                technicalInfoSection

                appDependenciesSection

                testFlightSection
            }
            .padding(.horizontal)
            .padding(.vertical)
            .customNavigationTitle("About")
        }
        .font(.customFont(fontFamily, style: .body))
    }

    private var heroSection: some View {
        VStack(alignment: .center, spacing: subsectionSpacing) {
            VStack(spacing: itemSpacing) {
                Text(appName)
                    .font(.customFont(fontFamily, style: .largeTitle))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Track as-needed medications with privacy and simplicity")
                    .font(.customFont(fontFamily, style: .title3))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Version \(version)")
                    .font(.customFont(fontFamily, style: .caption))
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

	private var developerSection: some View {
		VStack(alignment: .leading, spacing: subsectionSpacing) {
			Text("Connect with the Developer")
				.font(.customFont(fontFamily, style: .title2, weight: .semibold))
				.accessibilityAddTraits(.isHeader)

			if let url = mastodonURL {
				developerLink("Dan Hart on Mastodon", symbol: .atCircle, destination: url)
			}
			if let url = githubProfileURL {
				developerLink("Dan Hart on GitHub", symbol: .chevronLeftForwardslashChevronRight, destination: url)
			}
		}
	}

	private func developerLink(_ title: LocalizedStringKey, symbol: SFSymbol, destination: URL) -> some View {
		Link(destination: destination) {
			HStack(spacing: groupSpacing) {
				if !dynamicTypeSize.isAccessibilitySize {
					Image(systemSymbol: symbol)
						.accessibilityHidden(true)
				}
				Text(title)
					.multilineTextAlignment(.leading)
					.fixedSize(horizontal: false, vertical: true)
					.frame(maxWidth: .infinity, alignment: .leading)
				if !dynamicTypeSize.isAccessibilitySize {
					Image(systemSymbol: .arrowUpRight)
						.accessibilityHidden(true)
				}
			}
			.font(.customFont(fontFamily, style: .headline))
			.foregroundStyle(Color.accent.dynamicFilledButtonForeground)
			.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
		}
		.buttonStyle(.borderedProminent)
		.buttonBorderShape(.roundedRectangle(radius: cornerRadius12))
		.controlSize(.large)
		.tint(.accent)
	}

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: subsectionSpacing) {
            NavigationLink {
                SupportView()
            } label: {
                HStack(spacing: groupSpacing) {
                    Image(systemSymbol: .heart)
                        .font(.customFont(fontFamily, style: .title3))
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: textSpacing) {
                        Text("Support As Needed")
                            .font(.customFont(fontFamily, style: .headline))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Help keep this app free and open source")
                            .font(.customFont(fontFamily, style: .subheadline))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemSymbol: .chevronRight)
                        .font(.customFont(fontFamily, style: .caption))
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
                                    .font(.customFont(fontFamily, style: .headline))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("Design & Testing")
                                    .font(.customFont(fontFamily, style: .subheadline))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemSymbol: .arrowUpRightSquare)
                                .font(.customFont(fontFamily, style: .caption))
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
                                .font(.customFont(fontFamily, style: .headline))
                                .fontWeight(.semibold)
                            Text("Design & Testing")
                                .font(.customFont(fontFamily, style: .subheadline))
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
                                    .font(.customFont(fontFamily, style: .headline))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("Vision & Details")
                                    .font(.customFont(fontFamily, style: .subheadline))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemSymbol: .arrowUpRightSquare)
                                .font(.customFont(fontFamily, style: .caption))
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
                            .font(.customFont(fontFamily, style: .headline))
                            .fontWeight(.semibold)
                        Text("Support & Encouragement")
                            .font(.customFont(fontFamily, style: .subheadline))
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

                #if DEBUG
                    HStack {
                        Text("Distribution")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Bundle.main.distributionType)
                            .fontWeight(.medium)
                    }
                #else
                    if Bundle.main.isTestFlight {
                        HStack {
                            Text("Distribution")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("TestFlight")
                                .fontWeight(.medium)
                        }
                    }
                #endif

                if let url = githubURL {
                    HStack {
                        Text("Source Code")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Link("GitHub", destination: url)
                            .fontWeight(.medium)
                            .foregroundStyle(.accent)
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
                    .font(.customFont(fontFamily, style: .title3))
                    .foregroundColor(.accent)

                VStack(alignment: .leading, spacing: textSpacing) {
                    Text("App Dependencies")
                        .font(.customFont(fontFamily, style: .headline))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Third-party libraries used in this app")
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemSymbol: .chevronRight)
                    .font(.customFont(fontFamily, style: .caption))
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
