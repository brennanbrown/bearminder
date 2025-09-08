import Foundation

public enum LogLevel: String {
    case debug, info, warning, error
}

public protocol LoggerType {
    func log(_ level: LogLevel, _ message: @autoclosure () -> String, file: String, function: String, line: Int)
}

public final class Logger: LoggerType {
    public static let shared = Logger()
    private let queue = DispatchQueue(label: "Logging.Queue")

    public func log(_ level: LogLevel, _ message: @autoclosure () -> String, file: String = #fileID, function: String = #function, line: Int = #line) {
        #if DEBUG
        let ts = ISO8601DateFormatter().string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let rendered = message() // evaluate before capturing in escaping closure
        queue.async {
            print("[\(ts)] [\(level.rawValue.uppercased())] \(fileName)#\(line) \(function): \(rendered)")
        }
        #endif
    }

    public init() {}
}

public func LOG(_ level: LogLevel, _ message: @autoclosure () -> String, file: String = #fileID, function: String = #function, line: Int = #line) {
    Logger.shared.log(level, message(), file: file, function: function, line: line)
}
