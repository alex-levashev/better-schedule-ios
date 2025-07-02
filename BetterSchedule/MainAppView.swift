import SwiftUI
import Foundation

struct MainAppView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selection = 0
    @State private var dayLessons: [DayLessons] = []
    @State private var selectedTab: Int = 0
    @State private var personFullName: String = ""
    @State private var expirationDate: String = ""
    @State private var refreshTimer: Timer? = nil

    var body: some View {
        VStack {
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

                Button("Logout") {
                            authManager.logout()
                        }
                        .foregroundColor(.red)
                        .buttonStyle(.bordered)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
            }
            .padding(.horizontal)
            .padding(.top, 10)

            TabView(selection: $selectedTab) {
                        
                        ForEach(Array(dayLessons.enumerated()), id: \.offset) { index, day in
                            List {
                                Section(header: Text(formattedDate(day.date))) {
                                    ForEach(day.lessons.indices, id: \.self) { lessonIndex in
                                        let lesson = day.lessons[lessonIndex]
                                        VStack(alignment: .leading) {
                                            Text(lesson.name)
                                                .font(.headline)
                                            Text("\(lesson.teacher)")
                                            Text("🕒 \(lesson.start) – \(lesson.end)")
                                                .font(.caption)
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
                        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
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
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    func currentWeekdayIndex() -> Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let index = (weekday + 5) % 7
        return (index >= 5) ? 0 : index
    }
    
    func parseTokenInfo() {
        guard let token = authManager.token,
              let payload = decodeJWTPayload(token) else {
            personFullName = ""
            expirationDate = ""
            return
        }

        if let fullName = payload["Bakalari.PersonFullName"] as? String {
            personFullName = fullName
        } else {
            personFullName = ""
        }

        if let expUnix = payload["exp"] as? TimeInterval {
            let date = Date(timeIntervalSince1970: expUnix)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "cs_CZ")
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            expirationDate = formatter.string(from: date)
        } else {
            expirationDate = ""
        }
    }
    
    func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
        let segments = jwt.split(separator: ".")
        guard segments.count == 3 else { return nil }

        let payloadSegment = segments[1]
        var base64 = String(payloadSegment)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Pad with '=' to make length multiple of 4
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else { return nil }

        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any]
    }
    
    func checkAndRefreshTokenIfNeeded() {
        guard let token = authManager.token,
              let payload = decodeJWTPayload(token),
              let expUnix = payload["exp"] as? TimeInterval else {
            return
        }

        let expirationDate = Date(timeIntervalSince1970: expUnix)
        let now = Date()
        let remainingSeconds = expirationDate.timeIntervalSince(now)

        if remainingSeconds <= 3 {
            // Token is expiring or expired soon — refresh it
            authManager.refreshToken { success in
                DispatchQueue.main.async {
                    if success {
                        parseTokenInfo()  // Update UI with new token info
                        loadSchedule()    // Reload schedule with fresh token
                    } else {
                        print("Token refresh failed, user may need to log in again")
                        // Handle logout or show alert
                    }
                }
            }
        }
    }

    func loadSchedule() {
        guard let token = authManager.token else { return }

        TimetableLoader().loadTimetable(token: token) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.dayLessons = response
                case .failure(let error):
                    print("Ошибка загрузки расписания:", error.localizedDescription)
                }
            }
        }
    }
}
