import SwiftUI

enum SeerrPlayTheme {
    static let background = Color(red: 0.018, green: 0.016, blue: 0.027)
    static let surface = Color.white.opacity(0.08)
    static let magenta = Color(red: 1.0, green: 0.247, blue: 0.604)
    static let violet = Color(red: 0.557, green: 0.247, blue: 1.0)
    static let cyan = Color(red: 0.0, green: 0.949, blue: 0.996)
    static let available = Color(red: 0.25, green: 0.86, blue: 0.55)

    static let brandGradient = LinearGradient(
        colors: [magenta, violet, cyan],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct BrandMark: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 12 : 18) {
            ZStack {
                Circle().fill(SeerrPlayTheme.brandGradient)
                Text("S")
                    .font(.system(size: compact ? 28 : 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: compact ? 52 : 82, height: compact ? 52 : 82)

            Text("SeerrPlay")
                .font(.system(size: compact ? 30 : 48, weight: .bold, design: .rounded))
        }
    }
}

struct PageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.075, green: 0.043, blue: 0.11),
                SeerrPlayTheme.background,
                .black,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct AvailabilityBadge: View {
    let availability: Availability

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(availability == .available ? SeerrPlayTheme.available : SeerrPlayTheme.violet)
                .frame(width: 10, height: 10)
                .shadow(
                    color: availability == .available
                        ? SeerrPlayTheme.available.opacity(0.8)
                        : .clear,
                    radius: 8
                )
            Text(availability.title)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(.black.opacity(0.72), in: Capsule())
    }
}
