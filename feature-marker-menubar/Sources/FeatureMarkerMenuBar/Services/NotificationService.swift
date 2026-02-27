import UserNotifications

enum NotificationService {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    static func sendPhaseCompletion(feature: String, phaseName: String, phaseIndex: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Phase Completed"
        content.body = "\(feature): \(phaseName) completed"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "phase-\(feature)-\(phaseIndex)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
