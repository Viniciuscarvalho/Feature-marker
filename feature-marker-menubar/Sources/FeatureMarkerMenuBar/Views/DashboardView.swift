import SwiftUI

struct DashboardView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            switch appState.currentView {
            case .list:
                ListView(appState: appState)
            case .start:
                StartView(appState: appState)
            case .detail:
                DetailView(appState: appState)
            case .settings:
                SettingsView(appState: appState)
            }
        }
        .frame(width: 400, height: 500)
        .background(.regularMaterial)
    }
}
