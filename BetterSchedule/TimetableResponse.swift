import Foundation

struct TimetableResponse: Codable {
    let teachers: [Teacher]
    let hours: [Hour]
    let subjects: [Subject]
    let days: [Day]

    enum CodingKeys: String, CodingKey {
        case teachers = "Teachers"
        case hours = "Hours"
        case subjects = "Subjects"
        case days = "Days"
    }
}

struct Teacher: Codable {
    let id: String
    let abbrev: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case abbrev = "Abbrev"
        case name = "Name"
    }
}

struct Hour: Codable {
    let id: Int
    let caption: String
    let beginTime: String
    let endTime: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case caption = "Caption"
        case beginTime = "BeginTime"
        case endTime = "EndTime"
    }
}

struct Subject: Codable {
    let id: String
    let abbrev: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case abbrev = "Abbrev"
        case name = "Name"
    }
}

struct Day: Codable {
    let dayOfWeek: Int
    let date: String
    let atoms: [Atom]

    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "DayOfWeek"
        case date = "Date"
        case atoms = "Atoms"
    }
}

struct Atom: Codable {
    let hourId: Int
    let teacherId: String?
    let subjectId: String?
    let roomId: String?
    let theme: String?

    enum CodingKeys: String, CodingKey {
        case hourId = "HourId"
        case teacherId = "TeacherId"
        case subjectId = "SubjectId"
        case roomId = "RoomId"
        case theme = "Theme"
    }
}
