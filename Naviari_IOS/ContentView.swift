//
//  ContentView.swift
//  Naviari
//
//  Created by Ari Peltoniemi on 4.2.2026.
//

import SwiftUI
struct ContentView: View {
    var body: some View {
        TabView {
            RaceStartSelectorView()
                .tabItem {
                    Label("Race/Start", systemImage: "list.bullet")
                }

            RaceManagerView()
                .tabItem {
                    Label("Race Manager", systemImage: "clipboard")
                }

            BoatView()
                .tabItem {
                    Label("Boat", systemImage: "sailboat.fill")
                }
        }
    }
}
//test
private struct RaceStartSelectorView: View {
    var body: some View {
        Text("Select a race and start")
            .font(.title3)
            .multilineTextAlignment(.center)
            .padding()
    }
}

private struct RaceManagerView: View {
    var body: some View {
        Text("Here you manage race related data")
            .font(.title3)
            .multilineTextAlignment(.center)
            .padding()
    }
}

private struct BoatView: View {
    var body: some View {
        Text("Enter on race start")
            .font(.title3)
            .multilineTextAlignment(.center)
            .padding()
    }
}

#Preview {
    ContentView()
}
