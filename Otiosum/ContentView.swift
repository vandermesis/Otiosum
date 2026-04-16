//
//  ContentView.swift
//  Otiosum
//
//  Created by Marek Skrzelowski on 16/04/2026.
//

import SwiftUI

struct ContentView: View {
    @GestureState private var dragTranslation: CGFloat = .zero
    @State private var settledOffsetSeconds: Double = .zero

    private let pointsPerSecond: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { context in
            GeometryReader { proxy in
                let totalOffset = settledOffsetSeconds - (dragTranslation / pointsPerSecond)
                let centerDate = context.date.addingTimeInterval(totalOffset)

                ZStack {
                    MeterPanelBackgroundView()

                    CounterWheelsRowView(centerDate: centerDate)

                    GlassLineMagnifierView(date: centerDate)
                }
                .contentShape(.rect)
                .gesture(dragGesture)
                .ignoresSafeArea()
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let dragSeconds = -(value.translation.height / pointsPerSecond)
                let extraMomentum = -((value.predictedEndTranslation.height - value.translation.height) / pointsPerSecond)

                withAnimation(.spring(duration: 0.55, bounce: 0.22)) {
                    settledOffsetSeconds += Double(dragSeconds + (extraMomentum * 0.2))
                }
            }
    }
}

private struct MeterPanelBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.05),
                    Color(red: 0.10, green: 0.09, blue: 0.08),
                    Color(red: 0.03, green: 0.03, blue: 0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.clear)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.black.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.1
                        )
                        .padding()
                }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    .clear,
                    Color.black.opacity(0.22)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

private struct CounterWheelsRowView: View {
    let centerDate: Date
    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let wheelHeight = min(max(height * 0.82, 360), 760)
            let spacing: CGFloat = 4
            let horizontalInset: CGFloat = 10
            let totalSpacing = spacing * 6
            let availableWidth = max(width - totalSpacing - (horizontalInset * 2), 280)
            let widthUnit = availableWidth / 7.7
            let yearWidth = widthUnit * 1.5
            let weekdayWidth = widthUnit * 1.45
            let numericWidth = widthUnit

            HStack(spacing: spacing) {
                CounterWheelView(
                    title: "YR",
                    width: yearWidth,
                    height: wheelHeight,
                    tint: .orange,
                    labelProvider: YearLabelProvider(calendar: calendar),
                    date: centerDate
                )

                CounterWheelView(
                    title: "MO",
                    width: numericWidth,
                    height: wheelHeight,
                    tint: .mint,
                    labelProvider: MonthLabelProvider(calendar: calendar),
                    date: centerDate
                )

                CounterWheelView(
                    title: "DY",
                    width: numericWidth,
                    height: wheelHeight,
                    tint: .cyan,
                    labelProvider: DayLabelProvider(calendar: calendar),
                    date: centerDate
                )

                CounterWheelView(
                    title: "WD",
                    width: weekdayWidth,
                    height: wheelHeight,
                    tint: .green,
                    labelProvider: WeekdayLabelProvider(calendar: calendar),
                    date: centerDate
                )

                CounterWheelView(
                    title: "HR",
                    width: numericWidth,
                    height: wheelHeight,
                    tint: .yellow,
                    labelProvider: HourLabelProvider(calendar: calendar),
                    date: centerDate
                )

                CounterWheelView(
                    title: "MN",
                    width: numericWidth,
                    height: wheelHeight,
                    tint: .white,
                    labelProvider: MinuteLabelProvider(calendar: calendar),
                    date: centerDate
                )

                CounterWheelView(
                    title: "SC",
                    width: numericWidth,
                    height: wheelHeight,
                    tint: .red,
                    labelProvider: SecondLabelProvider(calendar: calendar),
                    date: centerDate
                )
            }
            .padding(.horizontal, horizontalInset)
            .frame(width: width, height: height)
        }
    }
}

private struct CounterWheelView<Provider: WheelLabelProvider>: View {
    let title: String
    let width: CGFloat
    let height: CGFloat
    let tint: Color
    let labelProvider: Provider
    let date: Date

    var body: some View {
        let rowHeight = max(height / 12.5, 32)
        let centerY = height / 2
        let visibleRows = Int((height / rowHeight).rounded(.up)) + 6
        let phase = labelProvider.phase(for: date)
        let focusBandHalfHeight = rowHeight * 0.55

        ZStack {
            RoundedRectangle(cornerRadius: width * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.74),
                            Color(red: 0.18, green: 0.17, blue: 0.15),
                            Color.black.opacity(0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: width * 0.22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.32), Color.black.opacity(0.42)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.45), radius: 16, y: 9)

            ForEach(-visibleRows...visibleRows, id: \.self) { offset in
                let y = centerY + ((CGFloat(offset) - phase.fractional) * rowHeight)
                let content = labelProvider.row(for: date, relativeOffset: offset)
                let distance = min(abs((y - centerY) / (height * 0.5)), 1)
                let majorOpacity = content.isMajor ? 1.0 : 0.52
                let withinFocusBand = abs(y - centerY) <= focusBandHalfHeight
                let baseScale = 1 - (distance * 0.22)
                let magnifiedScale = withinFocusBand ? baseScale * 1.24 : baseScale

                CounterWheelRowView(
                    value: content.label,
                    tickStrength: content.isMajor ? 1.0 : 0.55,
                    tint: tint
                )
                .frame(width: width * 0.86, height: rowHeight)
                .scaleEffect(magnifiedScale)
                .opacity((1 - (distance * 0.84)) * majorOpacity)
                .rotation3DEffect(
                    .degrees(Double((y - centerY) / (height * 0.5)) * -54),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.86
                )
                .position(x: width / 2, y: y)
            }

            VStack {
                Text(title)
                    .font(.caption2.monospaced().weight(.medium))
                    .foregroundStyle(tint.opacity(0.85))
                Spacer()
            }
            .padding(.top, 8)
        }
        .frame(width: width, height: height)
        .clipShape(.rect(cornerRadius: width * 0.22))
        .overlay {
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.7), location: 0.0),
                    .init(color: .clear, location: 0.18),
                    .init(color: .clear, location: 0.82),
                    .init(color: Color.black.opacity(0.7), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(.rect(cornerRadius: width * 0.22))
        }
    }
}

private struct CounterWheelRowView: View {
    let value: String
    let tickStrength: CGFloat
    let tint: Color

    private let tickLaneWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Text(value)
                .font(.caption.monospaced())
                .bold()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(1)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.leading, tickLaneWidth)
                .padding(.trailing, 3)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(tint.opacity(0.9))
                    .frame(width: 7, height: max(1.2, 10 * tickStrength))
                    .shadow(color: tint.opacity(0.55), radius: 2)
                    .frame(width: tickLaneWidth, alignment: .leading)
                    .padding(.leading, 1)

                Spacer(minLength: 0)
            }
        }
    }
}

private struct GlassLineMagnifierView: View {
    let date: Date

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let height = max(size.height * 0.09, 72)
            let lensShape = RoundedRectangle(cornerRadius: height * 0.28, style: .continuous)

            ZStack {
                CounterWheelsRowView(centerDate: date)
                    .scaleEffect(x: 1.02, y: 1.18, anchor: .center)
                    .frame(width: size.width, height: size.height)
                    .clipShape(lensShape)

                lensShape
                    .fill(.ultraThinMaterial.opacity(0.22))

                lensShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.7), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )

                VStack(spacing: height * 0.8) {
                    Rectangle()
                        .fill(Color.white.opacity(0.42))
                        .frame(height: 1)
                    Rectangle()
                        .fill(Color.white.opacity(0.42))
                        .frame(height: 1)
                }
                .padding(.horizontal, 6)
            }
            .frame(width: size.width - 26, height: height)
            .position(x: size.width / 2, y: size.height / 2)
            .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
        }
        .allowsHitTesting(false)
    }
}

private struct WheelPhase {
    let fractional: CGFloat
}

private struct WheelRowContent {
    let label: String
    let isMajor: Bool
}

private protocol WheelLabelProvider {
    func phase(for date: Date) -> WheelPhase
    func row(for date: Date, relativeOffset: Int) -> WheelRowContent
}

private struct YearLabelProvider: WheelLabelProvider {
    let calendar: Calendar

    func phase(for date: Date) -> WheelPhase {
        WheelPhase(fractional: 0)
    }

    func row(for date: Date, relativeOffset: Int) -> WheelRowContent {
        let adjusted = calendar.date(byAdding: .year, value: relativeOffset, to: date) ?? date
        let year = calendar.component(.year, from: adjusted)
        return WheelRowContent(label: String(year), isMajor: true)
    }
}

private struct MonthLabelProvider: WheelLabelProvider {
    let calendar: Calendar

    func phase(for date: Date) -> WheelPhase {
        WheelPhase(fractional: 0)
    }

    func row(for date: Date, relativeOffset: Int) -> WheelRowContent {
        let adjusted = calendar.date(byAdding: .month, value: relativeOffset, to: date) ?? date
        return WheelRowContent(label: adjusted.formatted(.dateTime.month(.twoDigits)), isMajor: true)
    }
}

private struct DayLabelProvider: WheelLabelProvider {
    let calendar: Calendar

    func phase(for date: Date) -> WheelPhase {
        WheelPhase(fractional: 0)
    }

    func row(for date: Date, relativeOffset: Int) -> WheelRowContent {
        let adjusted = calendar.date(byAdding: .day, value: relativeOffset, to: date) ?? date
        return WheelRowContent(label: adjusted.formatted(.dateTime.day(.twoDigits)), isMajor: true)
    }
}

private struct WeekdayLabelProvider: WheelLabelProvider {
    let calendar: Calendar

    func phase(for date: Date) -> WheelPhase {
        WheelPhase(fractional: 0)
    }

    func row(for date: Date, relativeOffset: Int) -> WheelRowContent {
        let adjusted = calendar.date(byAdding: .day, value: relativeOffset, to: date) ?? date
        return WheelRowContent(label: adjusted.formatted(.dateTime.weekday(.short)), isMajor: true)
    }
}

private struct HourLabelProvider: WheelLabelProvider {
    let calendar: Calendar

    func phase(for date: Date) -> WheelPhase {
        WheelPhase(fractional: 0)
    }

    func row(for date: Date, relativeOffset: Int) -> WheelRowContent {
        let adjusted = calendar.date(byAdding: .hour, value: relativeOffset, to: date) ?? date
        return WheelRowContent(label: adjusted.formatted(.dateTime.hour(.twoDigits(amPM: .omitted))), isMajor: true)
    }
}

private struct MinuteLabelProvider: WheelLabelProvider {
    let calendar: Calendar

    func phase(for date: Date) -> WheelPhase {
        WheelPhase(fractional: 0)
    }

    func row(for date: Date, relativeOffset: Int) -> WheelRowContent {
        let adjusted = calendar.date(byAdding: .minute, value: relativeOffset, to: date) ?? date
        let second = calendar.component(.second, from: adjusted)
        return WheelRowContent(
            label: adjusted.formatted(.dateTime.minute(.twoDigits)),
            isMajor: second == 0
        )
    }
}

private struct SecondLabelProvider: WheelLabelProvider {
    let calendar: Calendar

    func phase(for date: Date) -> WheelPhase {
        WheelPhase(fractional: 0)
    }

    func row(for date: Date, relativeOffset: Int) -> WheelRowContent {
        let adjusted = calendar.date(byAdding: .second, value: relativeOffset, to: date) ?? date
        let second = calendar.component(.second, from: adjusted)
        return WheelRowContent(
            label: adjusted.formatted(.dateTime.second(.twoDigits)),
            isMajor: second.isMultiple(of: 10)
        )
    }
}

#Preview {
    ContentView()
}
