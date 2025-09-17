import SwiftUI
import SFSafeSymbols

struct SettingsDisclaimersSectionView: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Disclaimers")
				.font(.title2)
				.fontWeight(.semibold)
			
			VStack(spacing: 12) {
				// Medical Disclaimer
				NavigationLink {
					MedicalDisclaimerDetailView()
				} label: {
					HStack(spacing: 12) {
						Image(systemSymbol: .exclamationmarkTriangle)
							.font(.system(size: 18, weight: .medium))
							.frame(width: 24, height: 24)
							.foregroundColor(.yellow)
						
						VStack(alignment: .leading, spacing: 2) {
							Text("Medical Disclaimer")
								.font(.body)
								.fontWeight(.medium)
							Text("Important medical advice information")
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
				
				// NIH/NLM Data Attribution
				NavigationLink {
					NIHDisclaimerDetailView()
				} label: {
					HStack(spacing: 12) {
						Image(systemSymbol: .buildingColumns)
							.font(.system(size: 18, weight: .medium))
							.frame(width: 24, height: 24)
							.foregroundColor(.accentColor)
						
						VStack(alignment: .leading, spacing: 2) {
							Text("Medical Data Sources")
								.font(.body)
								.fontWeight(.medium)
							Text("NIH/NLM RxNorm database citations")
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
	}
}

#if DEBUG
#Preview {
	NavigationView {
		SettingsDisclaimersSectionView()
			.padding()
	}
}
#endif