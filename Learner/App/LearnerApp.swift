//
//  LearnerApp.swift
//  Learner
//
//  Created by Njoud Altalal on 29/05/1448 AH.
//
import SwiftUI
import SwiftData

@main
struct LearnerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Color.brandOrange)
        }
        .modelContainer(for: [Goal.self, DayEntry.self])
    }
}
