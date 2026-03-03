import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedTab = 0
    @State private var homePath = NavigationPath()
    @State private var browsePath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var settingsPath = NavigationPath()
    @State private var homeScrollToTop = false

    var body: some View {
        if appState.hasCompletedOnboarding {
            mainTabView
        } else {
            OnboardingView()
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(path: $homePath, scrollToTop: $homeScrollToTop)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
                .accessibilityIdentifier("tab_home")
            GenreListView(path: $browsePath, switchToHome: { selectedTab = 0 })
                .tabItem { Label("Browse", systemImage: "square.grid.2x2") }
                .tag(1)
                .accessibilityIdentifier("tab_browse")
            SearchView(path: $searchPath, switchToHome: { selectedTab = 0 })
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(2)
                .accessibilityIdentifier("tab_search")
            SettingsView(path: $settingsPath, switchToHome: { selectedTab = 0 })
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
                .accessibilityIdentifier("tab_settings")
        }
        .onExitCommand {
            // When the Top Nav (tab bar) has focus, BACK should go to Home — not minimize the app
            if selectedTab != 0 {
                selectedTab = 0
            } else {
                homeScrollToTop = true
            }
        }
        .onChange(of: selectedTab) { oldValue, _ in
            // Discard navigation state of the tab we're leaving so it resets to root
            switch oldValue {
            case 0: homePath = NavigationPath()
            case 1: browsePath = NavigationPath()
            case 2: searchPath = NavigationPath()
            case 3: settingsPath = NavigationPath()
            default: break
            }
        }
    }
}
