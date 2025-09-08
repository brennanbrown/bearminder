import Foundation
import Models
import Logging
import KeychainSupport

public struct BeeminderClient {
    public enum ClientError: Error { case invalidURL, httpError(Int), decoding, other(Error) }

    private let username: String
    private let goal: String
    private let tokenProvider: () throws -> String
    private let session: URLSession

    public init(username: String, goal: String, tokenProvider: @escaping () throws -> String, session: URLSession = .shared) {
        self.username = username
        self.goal = goal
        self.tokenProvider = tokenProvider
        self.session = session
    }

    public func makeRequest(datapoint: BeeminderDatapoint) throws -> URLRequest {
        let token = try tokenProvider()
        guard let url = URL(string: "https://www.beeminder.com/api/v1/users/\(username)/goals/\(goal)/datapoints.json") else {
            throw ClientError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        var comps = URLComponents()
        comps.queryItems = [
            URLQueryItem(name: "auth_token", value: token),
            URLQueryItem(name: "value", value: String(datapoint.value)),
            URLQueryItem(name: "comment", value: datapoint.comment),
            URLQueryItem(name: "requestid", value: datapoint.requestID),
            URLQueryItem(name: "timestamp", value: String(Int(datapoint.timestamp)))
        ]
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        return req
    }

    @discardableResult
    public func postDatapoint(_ datapoint: BeeminderDatapoint, perform: Bool = false) async throws -> (Data, URLResponse) {
        let req = try makeRequest(datapoint: datapoint)
        if !perform {
            LOG(.info, "Prepared Beeminder request (dry-run) for value=\(datapoint.value) requestID=\(datapoint.requestID)")
            return (Data(), URLResponse())
        }
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ClientError.httpError(http.statusCode)
        }
        return (data, resp)
    }

    // (no helpers)
}
