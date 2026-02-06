import SwiftUI

enum StyleKit {
    static let ink = Color(red: 0.16, green: 0.19, blue: 0.27)
    static let softInk = Color(red: 0.45, green: 0.49, blue: 0.57)

    static let accentBlue = Color(red: 0.30, green: 0.51, blue: 0.98)
    static let accentMint = Color(red: 0.38, green: 0.85, blue: 0.73)
    static let accentPeach = Color(red: 1.00, green: 0.76, blue: 0.67)
    static let accentPink = Color(red: 0.98, green: 0.56, blue: 0.72)

    static let cardFill = Color.white.opacity(0.88)
    static let cardStroke = Color.white.opacity(0.95)
    static let softChip = Color(red: 0.92, green: 0.95, blue: 1.00)

    static let screenGradient = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.96, blue: 1.00),
            Color(red: 0.95, green: 0.98, blue: 1.00),
            Color(red: 1.00, green: 0.96, blue: 0.95)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = LinearGradient(
        colors: [accentBlue, Color(red: 0.53, green: 0.40, blue: 0.98)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct AppBackgroundLayer: View {
    var body: some View {
        ZStack {
            StyleKit.screenGradient

            Circle()
                .fill(StyleKit.accentMint.opacity(0.18))
                .frame(width: 220, height: 220)
                .offset(x: -140, y: -300)

            Circle()
                .fill(StyleKit.accentPink.opacity(0.16))
                .frame(width: 260, height: 260)
                .offset(x: 160, y: -220)

            Circle()
                .fill(StyleKit.accentPeach.opacity(0.16))
                .frame(width: 320, height: 320)
                .offset(x: -120, y: 320)
        }
        .ignoresSafeArea()
    }
}

private struct AppCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(StyleKit.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(StyleKit.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
    }
}

extension View {
    func appCard(padding: CGFloat = 14, radius: CGFloat = 16) -> some View {
        modifier(AppCardModifier(padding: padding, radius: radius))
    }
}

struct PrimaryFillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(StyleKit.primaryGradient.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SoftFillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(StyleKit.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(StyleKit.softChip.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
