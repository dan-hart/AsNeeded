import SwiftUI
import SFSafeSymbols

struct SupportView: View {
	@Environment(\.openURL) private var openURL
	
	var body: some View {
		NavigationView {
			ScrollView {
				VStack(alignment: .leading, spacing: 32) {
					// MARK: - Header
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Image(systemSymbol: .heart)
								.font(.title)
								.foregroundColor(.red)
							Text("Support As Needed")
								.font(.largeTitle)
								.fontWeight(.semibold)
						}
						Text("Help keep this app free, open source, and privacy-focused")
							.font(.subheadline)
							.foregroundColor(.secondary)
					}
					
					// MARK: - Core Values
					CoreValuesSection()
					
					// MARK: - Free & Open Source
					FreeAndOpenSourceSection()
					
					// MARK: - Buy Me a Coffee
					BuyMeACoffeeSection()
					
					// MARK: - Tip Jar
					TipJarSection()
					
					// MARK: - Subscriptions
					SubscriptionSection()
					
					Spacer(minLength: 32)
				}
				.padding()
			}
		}
	}
}

// MARK: - Core Values Section
private struct CoreValuesSection: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("CORE VALUES")
				.font(.headline)
				.fontWeight(.bold)
				.foregroundColor(.primary)
			
			VStack(alignment: .leading, spacing: 12) {
				CoreValueRow(
					icon: .wifiSlash,
					title: "Offline-first",
					description: "Works without internet connection"
				)
				
				CoreValueRow(
					icon: .externaldrive,
					title: "Local data only",
					description: "Your data stays on your device"
				)
				
				CoreValueRow(
					icon: .lock,
					title: "Privacy is a human right",
					description: "No tracking, no analytics, no data collection"
				)
				
				CoreValueRow(
					icon: .textPageBadgeMagnifyingglass,
					title: "Open & inspectable",
					description: "Source code available on GitHub"
				)
				
				CoreValueRow(
					icon: .dollarsignCircle,
					title: "Free & modifiable",
					description: "All features free, forever"
				)
				
				CoreValueRow(
					icon: .nosignApp,
					title: "No advertisements",
					description: "Never any ads, ever"
				)
			}
		}
	}
}

// MARK: - Core Value Row
private struct CoreValueRow: View {
	let icon: SFSymbol
	let title: String
	let description: String
	
	var body: some View {
		HStack(spacing: 12) {
			Image(systemSymbol: icon)
				.font(.system(size: 16, weight: .medium))
				.frame(width: 24, height: 24)
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
}

// MARK: - Free and Open Source Section
private struct FreeAndOpenSourceSection: View {
	@Environment(\.openURL) private var openURL
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Free & Open Source")
				.font(.title2)
				.fontWeight(.semibold)
			
			VStack(alignment: .leading, spacing: 16) {
				Text("As Needed will always be free to use with all features available to everyone. No advertisements, no premium tiers, no subscriptions required. The app is open source, meaning you can inspect the code, contribute improvements, or even build your own version.")
					.font(.body)
				
				Button {
					if let url = URL(string: "https://github.com/dan-hart/AsNeeded") {
						openURL(url)
					}
				} label: {
					HStack(spacing: 12) {
						Image(systemSymbol: .chevronLeftForwardslashChevronRight)
							.font(.system(size: 18, weight: .medium))
							.frame(width: 24, height: 24)
							.foregroundColor(.primary)
						
						VStack(alignment: .leading, spacing: 2) {
							Text("Contribute on GitHub")
								.font(.body)
								.fontWeight(.medium)
							Text("View source code, report issues, or contribute")
								.font(.caption)
								.foregroundColor(.secondary)
						}
						
						Spacer()
						
						Image(systemSymbol: .arrowUpRight)
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
	}
}

// MARK: - Buy Me a Coffee Section
private struct BuyMeACoffeeSection: View {
	@Environment(\.openURL) private var openURL
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Buy Me a Coffee")
				.font(.title2)
				.fontWeight(.semibold)
			
			VStack(alignment: .leading, spacing: 16) {
				Text("If As Needed has been helpful to you, consider buying me a coffee! Your support helps cover development costs and motivates continued improvements.")
					.font(.body)
				
				Button {
					if let url = URL(string: "https://buymeacoffee.com/codedbydan") {
						openURL(url)
					}
				} label: {
					HStack(spacing: 12) {
						Image(systemSymbol: .cupAndSaucerFill)
							.font(.system(size: 18, weight: .medium))
							.frame(width: 24, height: 24)
							.foregroundColor(.brown)
						
						VStack(alignment: .leading, spacing: 2) {
							Text("Buy Me a Coffee")
								.font(.body)
								.fontWeight(.medium)
							Text("Support development with a one-time donation")
								.font(.caption)
								.foregroundColor(.secondary)
						}
						
						Spacer()
						
						Image(systemSymbol: .arrowUpRight)
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
	}
}

// MARK: - Tip Jar Section
private struct TipJarSection: View {
	private let tipTiers = [
		(title: "Thanks", emoji: "👍", color: Color.green, price: "$0.99"),
		(title: "Cheers", emoji: "🥂", color: Color.orange, price: "$2.99"),
		(title: "Standing Ovation", emoji: "👏", color: Color.purple, price: "$4.99")
	]
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Tip Jar")
				.font(.title2)
				.fontWeight(.semibold)
			
			Text("Show your appreciation with a one-time tip. Every contribution helps keep the app free and open source.")
				.font(.body)
			
			LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
				ForEach(Array(tipTiers.enumerated()), id: \.offset) { _, tip in
					TipButton(tip: tip)
				}
			}
		}
	}
}

// MARK: - Tip Button
private struct TipButton: View {
	let tip: (title: String, emoji: String, color: Color, price: String)
	
	var body: some View {
		Button {
			// TODO: Implement RevenueCat tip purchase
			print("Tip selected")
		} label: {
			VStack(spacing: 8) {
				Text(tip.emoji)
					.font(.title2)
				
				Text(tip.title)
					.font(.caption)
					.fontWeight(.medium)
					.multilineTextAlignment(.center)
				
				Text(tip.price)
					.font(.caption2)
					.foregroundColor(.secondary)
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 16)
			.padding(.horizontal, 8)
			.background(tip.color.opacity(0.1))
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(tip.color, lineWidth: 1)
			)
			.cornerRadius(12)
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Subscription Section
private struct SubscriptionSection: View {
	private let subscriptionTiers = [
		(title: "Supporter", description: "Basic monthly support", icon: SFSymbol.heart, color: Color.blue, price: "$1.99"),
		(title: "Advocate", description: "Enhanced monthly support", icon: SFSymbol.handRaisedFill, color: Color.green, price: "$4.99"),
		(title: "Champion", description: "Premium monthly support", icon: SFSymbol.crownFill, color: Color.purple, price: "$9.99")
	]
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Monthly Support")
				.font(.title2)
				.fontWeight(.semibold)
			
			Text("Provide ongoing support with a monthly subscription. Help ensure the app's continued development and maintenance.")
				.font(.body)
			
			VStack(spacing: 12) {
				ForEach(Array(subscriptionTiers.enumerated()), id: \.offset) { _, subscription in
					SubscriptionButton(subscription: subscription)
				}
			}
		}
	}
}

// MARK: - Subscription Button
private struct SubscriptionButton: View {
	let subscription: (title: String, description: String, icon: SFSymbol, color: Color, price: String)
	
	var body: some View {
		Button {
			// TODO: Implement RevenueCat subscription purchase
			print("Subscription selected")
		} label: {
			HStack(spacing: 12) {
				Image(systemSymbol: subscription.icon)
					.font(.system(size: 18, weight: .medium))
					.frame(width: 24, height: 24)
					.foregroundColor(subscription.color)
				
				VStack(alignment: .leading, spacing: 2) {
					Text(subscription.title)
						.font(.body)
						.fontWeight(.medium)
					Text(subscription.description)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				
				Spacer()
				
				Text(subscription.price + "/month")
					.font(.caption)
					.fontWeight(.medium)
					.foregroundColor(subscription.color)
			}
			.padding(16)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(subscription.color, lineWidth: 1)
			)
			.cornerRadius(12)
		}
		.buttonStyle(.plain)
	}
}

#if DEBUG
#Preview {
	SupportView()
}
#endif
