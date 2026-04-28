import SwiftUI

struct PlannerBackground: View {
    let simple: Bool

    var body: some View {
        Group {
            if simple {
                Color(red: 0.97, green: 0.96, blue: 0.94)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.95),
                        Color(red: 0.94, green: 0.96, blue: 0.93),
                        Color(red: 0.93, green: 0.95, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
}

struct PlannerIcon: View {
    let symbolName: String
    let tintToken: String
    var compact: Bool = false

    var body: some View {
        Image(systemName: symbolName)
            .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
            .foregroundStyle(tintColor(token: tintToken))
            .frame(width: compact ? 28 : 42, height: compact ? 28 : 42)
            .background(tintColor(token: tintToken).opacity(0.14), in: RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
    }
}

struct StatusPill: View {
    let status: InferredProgressStatus

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.8), in: Capsule())
    }

    private var title: String {
        switch status {
        case .upcoming: "Upcoming"
        case .likelyInProgress: "Likely active"
        case .gentlyLate: "Sliding later"
        case .complete: "Done"
        case .protectedTime: "Protected"
        case .waiting: "Waiting"
        }
    }
}

func tintColor(token: String) -> Color {
    switch token {
    case "peach":
        Color(red: 0.90, green: 0.58, blue: 0.34)
    case "indigo":
        Color(red: 0.37, green: 0.41, blue: 0.78)
    case "sage":
        Color(red: 0.46, green: 0.62, blue: 0.50)
    case "lime":
        Color(red: 0.52, green: 0.71, blue: 0.22)
    case "sky":
        Color(red: 0.29, green: 0.58, blue: 0.84)
    case "amber":
        Color(red: 0.90, green: 0.70, blue: 0.20)
    case "violet":
        Color(red: 0.62, green: 0.48, blue: 0.82)
    case "teal":
        Color(red: 0.24, green: 0.62, blue: 0.62)
    case "sand":
        Color(red: 0.71, green: 0.64, blue: 0.52)
    case "mint":
        Color(red: 0.21, green: 0.67, blue: 0.54)
    default:
        Color(red: 0.40, green: 0.55, blue: 0.78)
    }
}

extension Int {
    var timeLabel: String {
        let hours = self / 60
        let minutes = self % 60
        return "\(hours.formatted(.number.precision(.integerLength(2)))):\(minutes.formatted(.number.precision(.integerLength(2))))"
    }
}

extension String {
    var testingIdentifier: String {
        replacing(" ", with: "-").lowercased()
    }
}
