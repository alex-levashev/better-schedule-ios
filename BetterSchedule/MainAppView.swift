import SwiftUI
import Foundation

struct MainAppView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // UI / data
    @State private var dayLessons: [DayLessons] = []
    @State private var selectedTab: Int = 0
    
    // User info extracted from JWT
    @State private var personFullName: String = ""
    @State private var expirationDate: String = ""
    
    // Timers & errors
    @State private var refreshTimer: Timer?
    @State private var scheduleError: ScheduleError?          // <- NEW
    
    // Lightweight Identifiable wrapper for alert(item:)
    struct ScheduleError: Identifiable {
        let id = UUID()
        let message: String
    }
    
    var body: some View {
        VStack {
            topBar
            timetableTabs
        }
        .alert(item: $scheduleError) { err in
            Alert(title: Text("Cannot Load Timetable"),
                  message: Text(err.message),
                  dismissButton: .default(Text("OK")) { scheduleError = nil })
        }
    }
}

// MARK: – Sub-views
private extension MainAppView {
    
    var topBar: some View {
        HStack(spacing: 12) {
            if !personFullName.isEmpty || !expirationDate.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if !personFullName.isEmpty {
                        Text(personFullName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    if !expirationDate.isEmpty {
                        Text("Exp: \(expirationDate)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            Button("Logout") { authManager.logout() }
                .foregroundColor(.red)
                .buttonStyle(.bordered)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    var timetableTabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(dayLessons.enumerated()), id: \.offset) { index, day in
                List {
                    Section(header: Text(formattedDate(day.date))) {
                        ForEach(day.lessons.indices, id: \.self) { i in
                            let lesson = day.lessons[i]
                            VStack(alignment: .leading) {
                                Text(lesson.name).font(.headline)
                                Text(lesson.teacher)
                                Text("🕒 \(lesson.start) – \(lesson.end)").font(.caption)
                            }
                        }
                    }
                }
                .tag(index + 2)
            }
        }
        .onAppear {
            selectedTab = 2 + currentWeekdayIndex()
            loadSchedule()
            parseTokenInfo()
            checkAndRefreshTokenIfNeeded()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 1,
                                                repeats: true) { _ in
                checkAndRefreshTokenIfNeeded()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
    }
}

// MARK: – Helpers
private extension MainAppView {
    
    func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "cs_CZ")
        fmt.dateStyle = .full
        return fmt.string(from: date)
    }
    
    func currentWeekdayIndex() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let index = (weekday + 5) % 7           // Mon = 0 … Sun = 6
        return (index >= 5) ? 0 : index         // Sat/Sun → Mon
    }
    
    func parseTokenInfo() {
        guard let token = authManager.token,
              let payload = decodeJWTPayload(token)
        else { personFullName = ""; expirationDate = ""; return }
        
        personFullName = payload["Bakalari.PersonFullName"] as? String ?? ""
        
        if let exp = payload["exp"] as? TimeInterval {
            let date = Date(timeIntervalSince1970: exp)
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "cs_CZ")
            fmt.dateStyle = .short
            fmt.timeStyle = .short
            expirationDate = fmt.string(from: date)
        } else {
            expirationDate = ""
        }
    }
    
    func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+")
                                     .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
    
    func checkAndRefreshTokenIfNeeded() {
        guard let token = authManager.token,
              let payload = decodeJWTPayload(token),
              let exp = payload["exp"] as? TimeInterval
        else { return }
        
        if Date(timeIntervalSince1970: exp).timeIntervalSinceNow <= 3 {
            authManager.refreshToken { success in
                if success {
                    parseTokenInfo()
                    loadSchedule()
                }
            }
        }
    }
    
    /// Loads schedule and sets `scheduleError` on failure ➜ triggers alert.
    func loadSchedule() {
        guard let token = authManager.token else { return }
        
        TimetableLoader().loadTimetable(token: token) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.dayLessons = response
                    self.scheduleError = nil             // clear any prior error
                case .failure(let error):
                    print("Timetable load error:", error.localizedDescription)
                    self.scheduleError = ScheduleError(message: error.localizedDescription)
                }
            }
        }
    }
}
