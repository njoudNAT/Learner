//
//  GoalDuration.swift
//  Learner
//
//  Created by Njoud Altalal on 30/05/1448 AH.
//
import Foundation

nonisolated enum GoalDuration: String, CaseIterable, Codable, Identifiable {
    case week
    case month
    case year

    var id: Self { self }

    var title: String { rawValue.capitalized }

    var totalDays: Int {
        switch self {
        case .week:  7
        case .month: 30
        case .year:  365
        }
    }

    var maxFreezes: Int {
        switch self {
        case .week:  2
        case .month: 8
        case .year:  96
        }
    }
}
