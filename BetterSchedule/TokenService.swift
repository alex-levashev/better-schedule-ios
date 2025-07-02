import Foundation

class TokenService {
    static func getToken(username: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://znamky.ggg.cz/api/login") else {
            completion(.failure(TokenError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let parameters = [
            "username": username,
            "password": password,
            "client_id": "ANDR",
            "grant_type": "password"
        ]

        let encodedParams = parameters.map { "\($0)=\($1)" }.joined(separator: "&")
        request.httpBody = encodedParams.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(TokenError.noData))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["access_token"] as? String {
                    completion(.success(token))
                } else {
                    completion(.failure(TokenError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }
    
    static func refreshTokenWithStoredCredentials(completion: @escaping (Result<String, Error>) -> Void) {
            guard
                let username = UserDefaults.standard.string(forKey: "username"),
                let password = UserDefaults.standard.string(forKey: "password")
            else {
                completion(.failure(TokenError.noStoredCredentials))
                return
            }
            
            getToken(username: username, password: password, completion: completion)
        }

    enum TokenError: Error {
        case invalidURL
        case noData
        case invalidResponse
        case noStoredCredentials
    }
}
