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
    private let calendar = Calendar.current

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { context in
            GeometryReader { proxy in
                let size = proxy.size
                let totalOffset = settledOffsetSeconds - (dragTranslation / pointsPerSecond)
                let centerDate = context.date.addingTimeInterval(totalOffset)

                ZStack {
                    WheelBackgroundView()

                    WheelGridView(
                        centerDate: centerDate,
                        size: size,
                        pointsPerSecond: pointsPerSecond,
                        calendar: calendar
                    )

                    MagnifierView(date: centerDate)
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

                withAnimation(.spring(duration: 0.55, bounce: 0.24)) {
                    settledOffsetSeconds += Double(dragSeconds + (extraMomentum * 0.18))
                }
            }
    }
}

private struct WheelBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.09),
                    Color(red: 0.09, green: 0.11, blue: 0.16),
                    Color(red: 0.03, green: 0.04, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.20),
                    Color.white.opacity(0.03),
                    .clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 420
            )
            .blendMode(.screen)
        }
    }
}

private struct WheelGridView: View {
    let centerDate: Date
    let size: CGSize
    let pointsPerSecond: CGFloat
    let calendar: Calendar

    var body: some View {
        let centerY = size.height / 2
        let centerSeconds = centerDate.timeIntervalSinceReferenceDate
        let centerWhole = floor(centerSeconds)
        let centerFraction = centerSeconds - centerWhole
        let visibleTicks = Int((size.height / pointsPerSecond).rounded(.up)) + 36

        ZStack {
            ForEach(-visibleTicks...visibleTicks, id: \.self) { index in
                let y = centerY + (CGFloat(Double(index) - centerFraction) * pointsPerSecond)
                let tickDate = Date(timeIntervalSinceReferenceDate: centerWhole + Double(index))
                let descriptor = TickDescriptor(date: tickDate, calendar: calendar)
                let distanceRatio = min(abs((y - centerY) / (size.height * 0.5)), 1)

                TickRowView(descriptor: descriptor, width: size.width)
                    .scaleEffect(1 - (distanceRatio * 0.24))
                    .opacity(1 - (distanceRatio * 0.82))
                    .rotation3DEffect(
                        .degrees(Double((y - centerY) / (size.height * 0.5)) * -58),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.84
                    )
                    .position(x: size.width / 2, y: y)
            }
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white, location: 0.12),
                    .init(color: .white, location: 0.88),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct TickRowView: View {
    let descriptor: TickDescriptor
    let width: CGFloat

    var body: some View {
        HStack(spacing: width * 0.02) {
            Capsule(style: .continuous)
                .fill(descriptor.color)
                .frame(width: width * descriptor.lengthFactor, height: descriptor.thickness)
                .shadow(color: descriptor.color.opacity(0.55), radius: 4, y: 0)

            Text(descriptor.label)
                .font(descriptor.font)
                .foregroundStyle(descriptor.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.55), radius: 1.5, y: 1)

            Spacer(minLength: 0)
        }
        .frame(width: width * 0.78)
    }
}

private struct MagnifierView: View {
    let date: Date

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let boxHeight = max(size.height * 0.14, 84)

            RoundedRectangle(cornerRadius: boxHeight * 0.24, style: .continuous)
                .fill(.thinMaterial.opacity(0.84))
                .overlay {
                    RoundedRectangle(cornerRadius: boxHeight * 0.24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.95), Color.white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.25
                        )
                }
                .overlay {
                    VStack {
                        Text(date, format: .dateTime.year().month(.abbreviated).day().weekday(.abbreviated))
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.white)
                        Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
                            .font(.largeTitle.monospacedDigit())
                            .bold()
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                }
                .shadow(color: .black.opacity(0.55), radius: 28, y: 12)
                .frame(width: size.width * 0.9, height: boxHeight)
                .position(x: size.width / 2, y: size.height / 2)
        }
        .allowsHitTesting(false)
    }
}

private struct TickDescriptor {
    let label: String
    let lengthFactor: CGFloat
    let thickness: CGFloat
    let color: Color
    let font: Font

    init(date: Date, calendar: Calendar) {
        let style = TimeWheelTickStyle.make(for: date, calendar: calendar)

        label = style.label
        lengthFactor = style.lengthFactor
        thickness = style.thickness

        switch style.tier {
        case .year:
            color = .orange
            font = .headline
        case .month:
            color = .mint
            font = .subheadline
        case .day:
            color = .cyan
            font = .subheadline
        case .hour:
            color = .white
            font = .body
        case .minute:
            color = .white.opacity(0.85)
            font = .caption
        case .tenSecond:
            color = .white.opacity(0.55)
            font = .caption2
        case .second:
            color = .white.opacity(0.32)
            font = .caption2
        }
    }
}

#Preview {
    ContentView()
}
