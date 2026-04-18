//
//  TimeWheelTickStyle.swift
//  Otiosum
//

import Foundation
import CoreGraphics

enum TimeWheelTickTier {
    case year
    case month
    case day
    case hour
    case minute
    case tenSecond
    case second
}

enum TimelineGridTier {
    case month
    case day
    case hour
    case quarterHour
    case minor
}

struct TimelineGridStyle {
    let tier: TimelineGridTier
    let label: String
    let lineOpacity: CGFloat
    let lineThickness: CGFloat

    static func make(
        for date: Date,
        calendar: Calendar = .current
    ) -> TimelineGridStyle {
        let components = calendar.dateComponents([.day, .hour, .minute], from: date)
        let minute = components.minute ?? 0
        let hour = components.hour ?? 0
        let day = components.day ?? 1

        if day == 1, hour == 0, minute == 0 {
            return TimelineGridStyle(
                tier: .month,
                label: date.formatted(.dateTime.month(.abbreviated).day()),
                lineOpacity: 0.32,
                lineThickness: 1.2
            )
        }

        if hour == 0, minute == 0 {
            return TimelineGridStyle(
                tier: .day,
                label: date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                lineOpacity: 0.26,
                lineThickness: 1.0
            )
        }

        if minute == 0 {
            return TimelineGridStyle(
                tier: .hour,
                label: date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))),
                lineOpacity: 0.20,
                lineThickness: 0.9
            )
        }

        if minute.isMultiple(of: 15) {
            return TimelineGridStyle(
                tier: .quarterHour,
                label: date.formatted(.dateTime.minute(.twoDigits)),
                lineOpacity: 0.12,
                lineThickness: 0.7
            )
        }

        return TimelineGridStyle(
            tier: .minor,
            label: "",
            lineOpacity: 0.08,
            lineThickness: 0.5
        )
    }
}

struct TimeWheelTickStyle {
    let tier: TimeWheelTickTier
    let label: String
    let lengthFactor: CGFloat
    let thickness: CGFloat

    static func make(
        for date: Date,
        calendar: Calendar = .current
    ) -> TimeWheelTickStyle {
        let components = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: date)

        let second = components.second ?? 0
        let minute = components.minute ?? 0
        let hour = components.hour ?? 0
        let day = components.day ?? 1
        let month = components.month ?? 1

        if month == 1, day == 1, hour == 0, minute == 0, second == 0 {
            return TimeWheelTickStyle(
                tier: .year,
                label: date.formatted(.dateTime.year()),
                lengthFactor: 0.22,
                thickness: 5
            )
        }

        if day == 1, hour == 0, minute == 0, second == 0 {
            return TimeWheelTickStyle(
                tier: .month,
                label: date.formatted(.dateTime.month(.abbreviated).year()),
                lengthFactor: 0.20,
                thickness: 4.5
            )
        }

        if hour == 0, minute == 0, second == 0 {
            return TimeWheelTickStyle(
                tier: .day,
                label: date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                lengthFactor: 0.18,
                thickness: 4
            )
        }

        if minute == 0, second == 0 {
            return TimeWheelTickStyle(
                tier: .hour,
                label: date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).day()),
                lengthFactor: 0.16,
                thickness: 3.5
            )
        }

        if second == 0 {
            return TimeWheelTickStyle(
                tier: .minute,
                label: date.formatted(.dateTime.minute()),
                lengthFactor: 0.14,
                thickness: 3
            )
        }

        if second.isMultiple(of: 10) {
            return TimeWheelTickStyle(
                tier: .tenSecond,
                label: date.formatted(.dateTime.second()),
                lengthFactor: 0.10,
                thickness: 2
            )
        }

        return TimeWheelTickStyle(
            tier: .second,
            label: "",
            lengthFactor: 0.055,
            thickness: 1.2
        )
    }
}
