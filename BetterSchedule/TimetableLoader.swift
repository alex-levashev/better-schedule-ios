import Foundation
import Combine

class TimetableLoader {
    func loadTimetable(token: String, completion: @escaping (Result<[DayLessons], Error>) -> Void) {
        guard let url = URL(string: "https://znamky.ggg.cz/api/3/timetable/actual") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            do {
                let result = try JSONDecoder().decode(TimetableResponse.self, from: data)
                let daysLessons = self.toDayLessons(
                    subjects: result.subjects, teachers: result.teachers, hours: result.hours,
                    days: result.days)
                completion(.success(daysLessons))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func toDayLessons(subjects: [Subject], teachers: [Teacher], hours: [Hour], days: [Day])
        -> [DayLessons]
    {
        let subjectMap = Dictionary(
            uniqueKeysWithValues: subjects.map {
                ($0.id.trimmingCharacters(in: .whitespaces), $0.name)
            })
        let teacherMap = Dictionary(uniqueKeysWithValues: teachers.map { ($0.id, $0.name) })
        let hourMap = Dictionary(uniqueKeysWithValues: hours.map { ($0.id, $0) })

        let dateFormatter = ISO8601DateFormatter()

        return days.compactMap { day in
            guard let date = dateFormatter.date(from: day.date) else {
                return nil
            }

            let lessons = day.atoms.compactMap { atom -> Lesson? in
                guard let subjectId = atom.subjectId?.trimmingCharacters(in: .whitespaces),
                    let subjectName = subjectMap[subjectId],
                    let teacherId = atom.teacherId,
                    let teacherName = teacherMap[teacherId],
                    let hour = hourMap[atom.hourId]
                else {
                    return nil
                }

                return Lesson(
                    name: subjectName,
                    teacher: teacherName,
                    start: hour.beginTime,
                    end: hour.endTime
                )
            }

            return DayLessons(date: date, lessons: lessons)
        }
    }
}
