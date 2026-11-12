//
//  AppClock.swift
//  Learner
//
//  Created by Njoud Altalal on 02/06/1448 AH.
//
import Foundation
import Observation

/// One clock for the whole app, so every page agrees on what "now" is.
/// In debug builds, `debugOffset` lets you time-travel to test streaks and freezes.
@MainActor
@Observable
final class AppClock {
    private(set) var current = Date.now
    var debugOffset: TimeInterval = 0

    var now: Date { current.addingTimeInterval(debugOffset) }

    func sync() {
        current = .now
    }
}
