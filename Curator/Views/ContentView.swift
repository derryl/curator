import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedTab = 0
    @State private var homePath = NavigationPath()
    @State private var browsePath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    var body: some View {
        if appState.hasCompletedOnboarding {
            mainTabView
        } else {
            OnboardingView()
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(path: $homePath)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            GenreListView(path: $browsePath)
                .tabItem { Label("Browse", systemImage: "square.grid.2x2") }
                .tag(1)
            SearchView(path: $searchPath)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(2)
            SettingsView(path: $settingsPath)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .onChange(of: selectedTab) {
            homePath = NavigationPath()
            browsePath = NavigationPath()
            searchPath = NavigationPath()
            settingsPath = NavigationPath()
        }
    }
}
