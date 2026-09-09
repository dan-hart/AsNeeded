import SFSafeSymbols
import SwiftUI

enum SubtleSupportLayoutStyle: Equatable {
	case detailed
	case compact

	init(dynamicTypeSize: DynamicTypeSize) {
		self = dynamicTypeSize >= .xxxLarge ? .compact : .detailed
	}
}

struct SubtleSupportView: View {
    let message: String
    @AppStorage(UserDefaultsKeys.hideSupportBanners) private var hideSupportBanners = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.fontFamily) private var fontFamily
    @ScaledMetric private var contentSpacing: CGFloat = 8
    @ScaledMetric private var dividerHeight: CGFloat = 20
    @ScaledMetric private var verticalPadding: CGFloat = 8
    @ScaledMetric private var horizontalPadding: CGFloat = 12
    @ScaledMetric private var cornerRadius: CGFloat = 8

    init(message: String = "If As Needed is helpful, consider supporting development") {
        self.message = message
    }

    var body: some View {
        if !hideSupportBanners {
            HStack(spacing: contentSpacing) {
                NavigationLink {
                    SupportView()
                } label: {
                    HStack(spacing: contentSpacing) {
                        Image(systemSymbol: .heart)
                            .font(.customFont(fontFamily, style: .caption, weight: .medium))
                            .foregroundColor(.red.opacity(0.6))

                        Text(layoutStyle == .compact ? "Support As Needed" : message)
                            .font(.customFont(fontFamily, style: .footnote))
                            .foregroundColor(.secondary)

                        Spacer()

                        Image(systemSymbol: .chevronRight)
                            .font(.customFont(fontFamily, style: .caption2))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: dividerHeight)

                Button {
                    hideSupportBanners = true
                } label: {
                    if layoutStyle == .compact {
                        Image(systemSymbol: .xmark)
                            .font(.customFont(fontFamily, style: .caption, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    } else {
                        Text("Hide")
                            .font(.customFont(fontFamily, style: .caption2))
                    }
                }
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
                .accessibilityLabel("Hide support suggestion")
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.tertiarySystemBackground))
                    .opacity(0.5)
            )
        }
    }

    private var layoutStyle: SubtleSupportLayoutStyle {
        SubtleSupportLayoutStyle(dynamicTypeSize: dynamicTypeSize)
    }
}

#if DEBUG
    #Preview {
        VStack(spacing: 16) {
            SubtleSupportView()
            SubtleSupportView(message: "Enjoying the app? Help keep it free and open source")
        }
        .padding()
    }
#endif
