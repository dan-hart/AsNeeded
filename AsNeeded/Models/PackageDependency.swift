import Foundation

/// Represents a Swift Package dependency with version and license information
struct PackageDependency: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let repositoryURL: URL
    let versionInfo: VersionInfo
    let license: License
    let isDirect: Bool

    /// Version or branch information for the package
    enum VersionInfo: Hashable {
        case version(String)
        case branch(String)

        var displayText: String {
            switch self {
            case let .version(version):
                return "v\(version)"
            case let .branch(branch):
                return branch
            }
        }
    }

    /// License type for the package
    enum License: String, CaseIterable {
        case mit = "MIT"
        case apache2 = "Apache 2.0"
        case bsd = "BSD"
        case gpl3 = "GNU GPLv3"
        case unknown = "Unknown"

        var displayName: String {
            rawValue
        }
    }

    /// Short commit hash (first 7 characters)
    let commitHash: String

    init(
        id: String,
        name: String,
        description: String,
        repositoryURL: URL,
        versionInfo: VersionInfo,
        commitHash: String,
        license: License,
        isDirect: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.repositoryURL = repositoryURL
        self.versionInfo = versionInfo
        self.commitHash = String(commitHash.prefix(7))
        self.license = license
        self.isDirect = isDirect
    }
}
