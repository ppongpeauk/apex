//
//  APIService.swift
//  ApexApp
//
//  Created by Arman Mahjoor on 9/27/25.
//

import Foundation
import Combine

class APIService {
    private let baseURL = "http://localhost:8000"
    private let fallbackURL = "http://172.29.136.205:8000"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.networkServiceType = .default
        self.session = URLSession(configuration: config)
    }

    func analyzeCSV(fileURL: URL) async throws -> ChartData {
        print("🚀 [APIService] Starting CSV analysis for file: \(fileURL.lastPathComponent)")

        // Try localhost first, then fallback to IP address
        let urls = [
            URL(string: "\(baseURL)/analyze-csv")!,
            URL(string: "\(fallbackURL)/analyze-csv")!
        ]

        for (index, url) in urls.enumerated() {
            print("📡 [APIService] Attempting connection \(index + 1)/\(urls.count) to: \(url)")

            do {
                return try await performAnalysis(fileURL: fileURL, targetURL: url)
            } catch {
                print("❌ [APIService] Attempt \(index + 1) failed: \(error)")
                if index == urls.count - 1 {
                    throw error
                }
                print("🔄 [APIService] Trying next URL...")
            }
        }

        throw APIError.networkError(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All connection attempts failed"]))
    }

    private func performAnalysis(fileURL: URL, targetURL: URL) async throws -> ChartData {
        // Read file data
        print("📄 [APIService] Reading file data...")
        let fileData = try Data(contentsOf: fileURL)
        print("✅ [APIService] File read successfully. Size: \(fileData.count) bytes")

        // Create multipart form data
        print("🔧 [APIService] Creating multipart form data...")
        let boundary = UUID().uuidString
        var request = URLRequest(url: targetURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        var body = Data()

        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        print("📦 [APIService] Request prepared. Body size: \(body.count) bytes")

        // Make request
        print("🌐 [APIService] Sending request to server...")
        do {
            let (data, response) = try await session.data(for: request)
            print("✅ [APIService] Received response from server")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [APIService] Invalid response type")
                throw APIError.invalidResponse
            }

            print("📊 [APIService] HTTP Status Code: \(httpResponse.statusCode)")
            print("📋 [APIService] Response Headers: \(httpResponse.allHeaderFields)")
            print("📦 [APIService] Response Data Size: \(data.count) bytes")

            guard httpResponse.statusCode == 200 else {
                print("❌ [APIService] HTTP Error - Status Code: \(httpResponse.statusCode)")
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    print("❌ [APIService] Server Error Details: \(detail)")
                    throw APIError.serverError(detail)
                }
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ [APIService] Raw Error Response: \(errorString)")
                }
                throw APIError.httpError(httpResponse.statusCode)
            }

            // Parse response
            print("🔍 [APIService] Parsing JSON response...")
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 [APIService] Raw JSON Response: \(jsonString)")
                }
                let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
                print("✅ [APIService] Successfully decoded API response")
                let chartData = ChartData(from: apiResponse)
                print("🎯 [APIService] Chart data created successfully")
                return chartData
            } catch {
                print("❌ [APIService] Decoding error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 [APIService] Failed to decode JSON: \(jsonString)")
                }
                throw APIError.decodingError(error)
            }
        } catch {
            print("❌ [APIService] Network request failed: \(error)")
            throw APIError.networkError(error)
        }
    }

    func checkServerHealth() async -> Bool {
        print("🏥 [APIService] Checking server health...")

        let urls = [
            URL(string: "\(baseURL)/health")!,
            URL(string: "\(fallbackURL)/health")!
        ]

        for (index, url) in urls.enumerated() {
            print("📡 [APIService] Health check attempt \(index + 1)/\(urls.count) to: \(url)")

            do {
                let (_, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ [APIService] Invalid health check response")
                    continue
                }

                print("🏥 [APIService] Health check status code: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("✅ [APIService] Server is healthy!")
                    return true
                }
            } catch {
                print("❌ [APIService] Health check attempt \(index + 1) failed: \(error)")
            }
        }

        print("❌ [APIService] All health check attempts failed")
        return false
    }

    func sendChatMessage(_ message: String, history: [[String: String]] = []) async throws -> String {
        print("💬 [APIService] Sending chat message: \(message)")

        let urls = [
            URL(string: "\(baseURL)/chat")!,
            URL(string: "\(fallbackURL)/chat")!
        ]

        for (index, url) in urls.enumerated() {
            print("📡 [APIService] Chat attempt \(index + 1)/\(urls.count) to: \(url)")

            do {
                return try await performChatRequest(message: message, history: history, targetURL: url)
            } catch {
                print("❌ [APIService] Chat attempt \(index + 1) failed: \(error)")
                if index == urls.count - 1 {
                    throw error
                }
                print("🔄 [APIService] Trying next URL...")
            }
        }

        throw APIError.networkError(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All chat attempts failed"]))
    }

    private func performChatRequest(message: String, history: [[String: String]] = [], targetURL: URL) async throws -> String {
        var request = URLRequest(url: targetURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let requestBody: [String: Any] = ["message": message, "history": history]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("🌐 [APIService] Sending chat request...")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("📊 [APIService] Chat response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.serverError(detail)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responseMessage = jsonResponse["response"] as? String {
            print("✅ [APIService] Received chat response")
            return responseMessage
        }

        throw APIError.decodingError(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid chat response format"]))
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
