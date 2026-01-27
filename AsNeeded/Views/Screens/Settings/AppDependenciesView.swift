import SFSafeSymbols
import SwiftUI

/// View displaying all Swift Package dependencies used in the app
///
/// **Appearance:**
/// - Grouped list of direct and transitive dependencies
/// - Each row shows package name, version/branch, commit hash, and license
/// - Tappable rows open the package's source repository
/// - Glass card design with proper spacing and accessibility
///
/// **Features:**
/// - Automatically parses Package.resolved for up-to-date information
/// - Displays license information with color-coded badges
/// - Shows commit hash in monospaced font for technical accuracy
/// - Full VoiceOver support with descriptive labels
///
/// **Use Cases:**
/// - Transparency about third-party code usage
/// - License compliance and attribution
/// - Developer reference for package versions
struct AppDependenciesView: View {
    @ScaledMetric private var sectionSpacing: CGFloat = 24
    @ScaledMetric private var subsectionSpacing: CGFloat = 16
    @ScaledMetric private var groupSpacing: CGFloat = 12
    @ScaledMetric private var itemSpacing: CGFloat = 8
    @ScaledMetric private var mediumSpacing: CGFloat = 6
    @ScaledMetric private var tightSpacing: CGFloat = 4
    @ScaledMetric private var cardPadding: CGFloat = 16
    @ScaledMetric private var mediumPadding: CGFloat = 8
    @ScaledMetric private var smallPadding: CGFloat = 4
    @ScaledMetric private var cornerRadius12: CGFloat = 12
    @ScaledMetric private var cornerRadius6: CGFloat = 6
    @ScaledMetric private var iconSize28: CGFloat = 28
    @Environment(\.openURL) private var openURL
    @Environment(\.fontFamily) private var fontFamily
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let directDependencies: [PackageDependency]
    private let transitiveDependencies: [PackageDependency]

    init() {
        let manager = PackageDependencyManager.shared
        directDependencies = manager.getDirectDependencies()
        transitiveDependencies = manager.getTransitiveDependencies()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                headerSection

                if !directDependencies.isEmpty {
                    directDependenciesSection
                }

                if !transitiveDependencies.isEmpty {
                    transitiveDependenciesSection
                }

                footerSection
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .navigationTitle("App Dependencies")
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            Text("Open Source Libraries")
                .font(.customFont(fontFamily, style: .title2, weight: .semibold))

            Text("This app is built with these third-party Swift packages. Tap any package to view its source code.")
                .font(.customFont(fontFamily, style: .subheadline))
                .foregroundStyle(.secondary)
        }
    }

    private var directDependenciesSection: some View {
        VStack(alignment: .leading, spacing: groupSpacing) {
            Text("Direct Dependencies")
                .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: itemSpacing) {
                ForEach(directDependencies) { dependency in
                    dependencyRow(dependency)
                }
            }
        }
    }

    private var transitiveDependenciesSection: some View {
        VStack(alignment: .leading, spacing: groupSpacing) {
            Text("Transitive Dependencies")
                .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("These packages are automatically included by the direct dependencies above.")
                .font(.customFont(fontFamily, style: .caption))
                .foregroundStyle(.tertiary)

            VStack(spacing: itemSpacing) {
                ForEach(transitiveDependencies) { dependency in
                    dependencyRow(dependency)
                }
            }
        }
    }

    private func dependencyRow(_ dependency: PackageDependency) -> some View {
        Button {
            openURL(dependency.repositoryURL)
        } label: {
            if dynamicTypeSize.isAccessibilitySize {
                // Accessibility layout - vertical stacking
                VStack(alignment: .leading, spacing: subsectionSpacing) {
                    // Icon and name
                    HStack(spacing: groupSpacing) {
                        Image(systemSymbol: .shippingboxFill)
                            .font(.title2)
                            .foregroundStyle(.accent)

                        Text(dependency.name)
                            .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                            .foregroundStyle(.primary)
                            .noTruncate()
                    }

                    // Description
                    Text(dependency.description)
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundStyle(.secondary)
                        .noTruncate()

                    // Metadata - stacked vertically
                    VStack(alignment: .leading, spacing: tightSpacing) {
                        licenseBadge(for: dependency.license)

                        Text(dependency.versionInfo.displayText)
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundStyle(.secondary)

                        Text(dependency.commitHash)
                            .font(.customFont(fontFamily, style: .caption).monospaced())
                            .foregroundStyle(.tertiary)
                    }

                    // Link indicator
                    HStack {
                        Spacer()
                        Image(systemSymbol: .arrowUpRightSquare)
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(cardPadding)
                .background(.regularMaterial)
                .cornerRadius(cornerRadius12)
            } else {
                // Standard layout - horizontal with improved wrapping
                HStack(spacing: groupSpacing) {
                    // Package icon
                    Image(systemSymbol: .shippingboxFill)
                        .font(.title2)
                        .frame(width: iconSize28, height: iconSize28)
                        .foregroundStyle(.accent)

                    // Content
                    VStack(alignment: .leading, spacing: mediumSpacing) {
                        // Package name
                        Text(dependency.name)
                            .font(.customFont(fontFamily, style: .headline, weight: .semibold))
                            .foregroundStyle(.primary)
                            .noTruncate()

                        // Description
                        Text(dependency.description)
                            .font(.customFont(fontFamily, style: .subheadline))
                            .foregroundStyle(.secondary)
                            .noTruncate()

                        // Metadata row - improved to prevent overflow
                        VStack(alignment: .leading, spacing: tightSpacing) {
                            HStack(spacing: itemSpacing) {
                                // License badge
                                licenseBadge(for: dependency.license)

                                Text("•")
                                    .font(.customFont(fontFamily, style: .caption2))
                                    .foregroundStyle(.tertiary)

                                // Version
                                Text(dependency.versionInfo.displayText)
                                    .font(.customFont(fontFamily, style: .caption))
                                    .foregroundStyle(.secondary)
                            }

                            // Commit hash on separate line for better wrapping
                            Text(dependency.commitHash)
                                .font(.customFont(fontFamily, style: .caption).monospaced())
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer(minLength: itemSpacing)

                    // External link indicator
                    Image(systemSymbol: .arrowUpRightSquare)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .padding(cardPadding)
                .background(.regularMaterial)
                .cornerRadius(cornerRadius12)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dependency.name), \(dependency.description), version \(dependency.versionInfo.displayText), \(dependency.license.displayName) license")
        .accessibilityHint("Open source repository in browser")
    }

    private func licenseBadge(for license: PackageDependency.License) -> some View {
        Text(license.displayName)
            .font(.customFont(fontFamily, style: .caption2, weight: .bold))
            .foregroundStyle(licenseForegroundColor(for: license))
            .noTruncate()
            .padding(.horizontal, mediumPadding)
            .padding(.vertical, smallPadding)
            .background(licenseBackgroundColor(for: license))
            .cornerRadius(cornerRadius6)
    }

    private func licenseBackgroundColor(for license: PackageDependency.License) -> Color {
        switch license {
        case .mit:
            return .brown
        case .apache2:
            return .orange
        case .bsd:
            return .orange
        case .gpl3:
            return .green
        case .unknown:
            return .secondary
        }
    }

    private func licenseForegroundColor(for license: PackageDependency.License) -> Color {
        // Use the contrast extension to ensure readability
        switch license {
        case .mit, .apache2, .bsd, .gpl3:
            return licenseBackgroundColor(for: license).contrastingForegroundColor()
        case .unknown:
            return .white
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            Text("License Information")
                .font(.customFont(fontFamily, style: .caption, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Each package is licensed under its respective open source license. Click on any package to view its full license text in the source repository.")
                .font(.customFont(fontFamily, style: .caption))
                .foregroundStyle(.tertiary)
        }
        .padding(cardPadding)
        .background(.regularMaterial)
        .cornerRadius(cornerRadius12)
    }
}

#if DEBUG
    #Preview {
        NavigationView {
            AppDependenciesView()
        }
    }
#endif
