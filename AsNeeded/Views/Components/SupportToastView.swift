import SFSafeSymbols
import SwiftUI

struct SupportToastView: View {
    let message: String
    let supportMessage: String
    let isVisible: Bool
    let onDismiss: () -> Void
    let onSupportTapped: () -> Void
    @AppStorage(UserDefaultsKeys.hideSupportBanners) private var hideSupportBanners = false

    @ScaledMetric private var mainSpacing: CGFloat = 16
    @ScaledMetric private var iconHSpacing: CGFloat = 6
    @ScaledMetric private var buttonHPadding: CGFloat = 20
    @ScaledMetric private var buttonVPadding: CGFloat = 10
    @ScaledMetric private var buttonCornerRadius: CGFloat = 10
    @ScaledMetric private var buttonBorderWidth: CGFloat = 1
    @ScaledMetric private var dontShowPaddingH: CGFloat = 16
    @ScaledMetric private var dontShowPaddingV: CGFloat = 8
    @ScaledMetric private var dontShowCornerRadius: CGFloat = 8
    @ScaledMetric private var dismissButtonSize: CGFloat = 44
    @ScaledMetric private var toastPadding: CGFloat = 24
    @ScaledMetric private var toastMaxWidth: CGFloat = 320
    @ScaledMetric private var toastCornerRadius: CGFloat = 20
    @ScaledMetric private var toastBorderWidth: CGFloat = 1

    init(
        message: String,
        supportMessage: String = "Support As Needed",
        isVisible: Bool,
        onDismiss: @escaping () -> Void,
        onSupportTapped: @escaping () -> Void
    ) {
        self.message = message
        self.supportMessage = supportMessage
        self.isVisible = isVisible
        self.onDismiss = onDismiss
        self.onSupportTapped = onSupportTapped
    }

    var body: some View {
        if isVisible && !hideSupportBanners {
            GeometryReader { geometry in
                VStack(spacing: mainSpacing) {
                    // Success indicator with animation
                    Image(systemSymbol: .checkmarkCircleFill)
                        .font(.largeTitle.weight(.medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isVisible ? 1.0 : 0.5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isVisible)

                    // Main message
                    Text(message)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    // Support button
                    Button(action: onSupportTapped) {
                        HStack(spacing: iconHSpacing) {
                            Image(systemSymbol: .heartFill)
                                .font(.caption)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.red, .pink],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            Text(supportMessage)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.accent)
                        }
                        .padding(.horizontal, buttonHPadding)
                        .padding(.vertical, buttonVPadding)
                        .background(
                            RoundedRectangle(cornerRadius: buttonCornerRadius)
                                .fill(.accent.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: buttonCornerRadius)
                                .strokeBorder(.accent.opacity(0.3), lineWidth: buttonBorderWidth)
                        )
                    }
                    .buttonStyle(.plain)

                    // Don't Show Again button
                    Button {
                        hideSupportBanners = true
                        onDismiss()
                    } label: {
                        Text("Don't Show Again")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, dontShowPaddingH)
                            .padding(.vertical, dontShowPaddingV)
                            .background {
                                RoundedRectangle(cornerRadius: dontShowCornerRadius, style: .continuous)
                                    .fill(.regularMaterial)
                            }
                    }
                    .buttonStyle(.plain)

                    // Dismiss button with proper tap target
                    Button(action: onDismiss) {
                        Image(systemSymbol: .xmarkCircleFill)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: dismissButtonSize, height: dismissButtonSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(toastPadding)
                .frame(maxWidth: toastMaxWidth)
                .background(
                    RoundedRectangle(cornerRadius: toastCornerRadius)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: toastCornerRadius)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: toastBorderWidth
                                )
                        )
                        .overlay(
                            // Specular highlight for premium glass effect
                            RoundedRectangle(cornerRadius: toastCornerRadius)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.3),
                                            .clear,
                                            .white.opacity(0.1),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .blendMode(.overlay)
                        )
                )
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
                .scaleEffect(isVisible ? 1.0 : 0.9)
                .opacity(isVisible ? 1.0 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
            }
            .transition(.opacity.combined(with: .scale))
            .zIndex(999) // Ensure it appears above other content
        }
    }
}

#if DEBUG
    #Preview {
        VStack {
            Spacer()
            SupportToastView(
                message: "Dose logged successfully",
                isVisible: true,
                onDismiss: {},
                onSupportTapped: {}
            )
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
#endif
