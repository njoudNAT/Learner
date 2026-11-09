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
                   // Forces dark mode for the whole app (all screens inherit it).
                   .preferredColorScheme(.dark)
                   // Orange is the default tint: glass buttons, toolbar items, alerts.
                   .tint(Color.brandOrange)
           }
           // One container holds both models, so the calendar can read all history.
           .modelContainer(for: [Goal.self, DayEntry.self])
       }
   }
    
