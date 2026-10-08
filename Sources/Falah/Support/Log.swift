import os

enum Log {
    static let subsystem = "com.yusufkhan.falah"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let clock = Logger(subsystem: subsystem, category: "clock")
    static let engine = Logger(subsystem: subsystem, category: "engine")
}
