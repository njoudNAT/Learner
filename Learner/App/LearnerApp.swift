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
    @State private var clock = AppClock()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(clock)
                .preferredColorScheme(.dark)
                .tint(Color.brandOrange)
        }
        .modelContainer(for: [Goal.self, DayEntry.self])
    }
}
