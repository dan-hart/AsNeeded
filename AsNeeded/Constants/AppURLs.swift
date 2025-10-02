// AppURLs.swift
// Centralized constants for all app-related URLs

import Foundation

/// Centralized URL constants for maintainability
public enum AppURLs {
	// MARK: - TestFlight
	/// TestFlight beta program join URL
	static let testFlightBeta = URL(string: "https://testflight.apple.com/join/ZgW1r5Fd")

	// MARK: - GitHub
	/// GitHub repository URL
	static let githubRepository = URL(string: "https://github.com/dan-hart/AsNeeded")

	/// GitHub issues URL
	static let githubIssues = URL(string: "https://github.com/dan-hart/AsNeeded/issues/new")

	/// GitHub developer profile URL
	static let githubProfile = URL(string: "https://github.com/dan-hart")

	// MARK: - Social
	/// Developer's Mastodon profile
	static let mastodon = URL(string: "https://mas.to/@codedbydan")

	// MARK: - Contributors
	/// Christine Wang's portfolio URL
	static let christineWang = URL(string: "https://christinewang.design/")

	// MARK: - Legal
	/// Apple's standard EULA
	static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

	/// Privacy policy on GitHub
	static let privacyPolicy = URL(string: "https://github.com/dan-hart/AsNeeded/blob/develop/PRIVACY.md")
}
