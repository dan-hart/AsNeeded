import SFSafeSymbols
import SwiftUI

enum SupportSuggestionLayoutStyle: Equatable {
	case detailed
	case hidden
	case compact

	init(dynamicTypeSize: DynamicTypeSize) {
		if dynamicTypeSize.isAccessibilitySize {
			self = .compact
		} else if dynamicTypeSize == .xxxLarge {
			self = .hidden
		} else {
			self = .detailed
		}
	}
}

struct SupportSuggestionView: View {
    @AppStorage(UserDefaultsKeys.hideSupportBanners) private var hideSupportBanners = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.fontFamily) private var fontFamily
    @ScaledMetric private var containerSpacing: CGFloat = 8
    @ScaledMetric private var contentSpacing: CGFloat = 14
    @ScaledMetric private var iconSize: CGFloat = 36
    @ScaledMetric private var labelSpacing: CGFloat = 3
    @ScaledMetric private var cardPadding: CGFloat = 16
    @ScaledMetric private var cornerRadius: CGFloat = 16
    @ScaledMetric private var buttonVerticalPadding: CGFloat = 8
    @ScaledMetric private var buttonCornerRadius: CGFloat = 8
    @ScaledMetric private var borderWidth: CGFloat = 1

    var body: some View {
        if !hideSupportBanners {
			switch SupportSuggestionLayoutStyle(dynamicTypeSize: dynamicTypeSize) {
			case .detailed:
				detailedSuggestion

			case .hidden:
				EmptyView()

			case .compact:
				SubtleSupportView(message: "Consider supporting continued development")
					.padding(.horizontal, cardPadding)
					.padding(.top, containerSpacing)
			}
        }
    }

    private var detailedSuggestion: some View {
        VStack(spacing: containerSpacing) {
            NavigationLink {
                SupportView()
            } label: {
                HStack(spacing: contentSpacing) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.1), Color.pink.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: iconSize, height: iconSize)

                        Image(systemSymbol: .heart)
                            .font(.customFont(fontFamily, style: .callout, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.red, Color.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(alignment: .leading, spacing: labelSpacing) {
                        Text("Enjoying As Needed?")
                            .font(.customFont(fontFamily, style: .subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Consider supporting continued development")
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemSymbol: .chevronRight)
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.systemBackground),
                                    Color(.secondarySystemBackground).opacity(0.5),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.red.opacity(0.2),
                                    Color.pink.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: borderWidth
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                hideSupportBanners = true
            } label: {
                Text("Don't Show Again")
                    .font(.customFont(fontFamily, style: .caption))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, buttonVerticalPadding)
                    .background {
                        RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous)
                            .fill(.regularMaterial)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, cardPadding)
        .padding(.top, containerSpacing)
    }
}

#if DEBUG
    #Preview {
        List {
            SupportSuggestionView()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }
#endif
