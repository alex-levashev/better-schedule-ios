import Foundation

struct DayLessons {
    let date: Date
    let lessons: [Lesson]
}

struct Lesson {
    let name: String
    let teacher: String
    let start: String
    let end: String
}
