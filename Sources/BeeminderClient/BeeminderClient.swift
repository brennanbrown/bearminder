import Foundation
import Models
import Logging
import KeychainSupport

public struct BeeminderClient {
    public enum ClientError: Error {
        case invalidURL
        case httpError(Int)
        case rateLimited(retryAfter: TimeInterval?)
        case networkError(Error)
        case decoding
        case other(Error)
        
        var isRetryable: Bool {
            switch self {
            case .rateLimited, .networkError: return true
            case .httpError(let code): return code >= 500 // Server errors are retryable
            default: return false
            }
        }
    }

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
        
        do {
            let (data, resp) = try await session.data(for: req)
            
            if let http = resp as? HTTPURLResponse {
                switch http.statusCode {
                case 200...299:
                    LOG(.info, "Successfully posted datapoint value=\(datapoint.value) requestID=\(datapoint.requestID)")
                    return (data, resp)
                    
                case 429:
                    // Rate limited - check for Retry-After header
                    let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { TimeInterval($0) }
                    LOG(.warning, "Rate limited (429). Retry-After: \(retryAfter?.description ?? "not specified")")
                    throw ClientError.rateLimited(retryAfter: retryAfter)
                    
                case 400...499:
                    // Client errors (auth, bad request, etc.) - not retryable
                    LOG(.error, "Client error \(http.statusCode) posting to Beeminder")
                    throw ClientError.httpError(http.statusCode)
                    
                case 500...599:
                    // Server errors - retryable
                    LOG(.error, "Server error \(http.statusCode) from Beeminder")
                    throw ClientError.httpError(http.statusCode)
                    
                default:
                    LOG(.error, "Unexpected HTTP status \(http.statusCode)")
                    throw ClientError.httpError(http.statusCode)
                }
            }
            return (data, resp)
            
        } catch let error as ClientError {
            throw error
        } catch {
            // Network errors (no connection, timeout, etc.)
            LOG(.error, "Network error posting to Beeminder: \(error.localizedDescription)")
            throw ClientError.networkError(error)
        }
    }

    // Lightweight credential probe (no writes)
    public func validateCredentials() async -> Bool {
        do {
            let token = try tokenProvider()
            guard !username.isEmpty, !token.isEmpty,
                  let url = URL(string: "https://www.beeminder.com/api/v1/users/\(username).json?auth_token=\(token)") else {
                return false
            }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            let (_, resp) = try await session.data(for: req)
            if let http = resp as? HTTPURLResponse { return (200...299).contains(http.statusCode) }
            return false
        } catch {
            LOG(.warning, "Beeminder validate failed: \(error)")
            return false
        }
    }
}
