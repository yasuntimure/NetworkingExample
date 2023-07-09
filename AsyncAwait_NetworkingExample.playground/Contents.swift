import Foundation

// Binance API = "https://api.binance.com/"


// MARK: - HTTPMethod

public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
}


// MARK: - HTTPHeaders

public typealias HTTPHeaders = [String : String]?

/// A dictionary of parameters to apply to a `URLRequest`.
public typealias Parameters = [String: Any]


// MARK: - HTTPTask

public enum HTTPTask {
    case requestPlain
    case requestParameters(parameters: Parameters?, encoding: ParameterEncoding)
    // Other tasks
}

public enum ParameterEncoding {
    case url
    // Other encodings
}


// MARK: - Endpoint

public protocol Endpoint {
    var request: URLRequest? { get }
    var httpMethod: HTTPMethod { get }
    var httpHeaders: HTTPHeaders? { get }
    var httpTask: HTTPTask { get }
    var useToken: Bool { get }
    var scheme: String { get }
    var host: String { get }
}

extension Endpoint {
    
    public var scheme: String { "https" }
    
    public var host: String { "api.binance.com" }
    
    public func request(_ endpoint: String) -> URLRequest? {
        var urlComponents = URLComponents()
        urlComponents.scheme = scheme
        urlComponents.host = host
        urlComponents.path = endpoint
        guard let url = urlComponents.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        
        if let httpHeaders = httpHeaders {
            dump("Http Headers: \(String(describing: httpHeaders))")
            httpHeaders?.forEach { element in // element ["X-MBX-APIKEY": "binance_api_key_here"] as an example
                request.setValue(
                    element.value,
                    forHTTPHeaderField: element.key
                )
            }
        }
        return request
    }
}


// MARK: - Extend Encodable to convert to a dictionary

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError()
        }
        return dictionary
    }
}


// MARK: - Ticker Price Request Model

public struct TickerPriceDTO: Codable {
    var symbol: String?
}


// MARK: - Ticker Price List Response

typealias TickerPriceResponse = [TickerPrice]

public struct TickerPrice: Decodable {
    let symbol: String
    let price: String
}


// MARK: - Ticker Endpoint

public enum TickerEndpoint: Endpoint {
    
    case tickerPrice(dto: TickerPriceDTO)
    
    public var request: URLRequest? {
        switch self {
        case .tickerPrice:
            return request("/api/v3/ticker/price")
        }
    }
    
    public var httpMethod: HTTPMethod {
        switch self {
        case .tickerPrice:
            return .GET
        }
    }
    
    public var httpHeaders: HTTPHeaders? {
        switch self {
        case .tickerPrice: return nil
        }
    }
    
    public var httpTask: HTTPTask {
        switch self {
        case .tickerPrice(let dto):
            return .requestParameters(parameters: try? dto.asDictionary(), encoding: .url)
        }
    }
    
    public var useToken: Bool {
        switch self {
        case .tickerPrice:
            return false
        }
    }
}


// MARK: - NetworkError

public enum NetworkError: Error {
    case invalidURL
    case requestFailed
    case responseUnsuccessful
    case invalidData
    case jsonDecodingError
    case notFound
    case badRequest
    case unknownError
    case invalidRequest
}


// MARK: - NetworkingProtocol

public protocol NetworkingProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

// MARK: - Networking Class

public final class Networking: NetworkingProtocol {
    public func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        guard let request = endpoint.request else { throw NetworkError.invalidRequest }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.responseUnsuccessful }
        
        switch httpResponse.statusCode {
        case 200...299:
            let responseObject = try JSONDecoder().decode(T.self, from: data)
            return responseObject
        case 400...499:
            throw NetworkError.notFound
        case 500...599:
            throw NetworkError.badRequest
        default:
            throw NetworkError.unknownError
        }
    }
}


// MARK: - USAGE

let networking = Networking()
let tickerPriceDTO = TickerPriceDTO(symbol: nil)
let endpoint = TickerEndpoint.tickerPrice(dto: tickerPriceDTO)

Task {
    do {
        let responseArray: TickerPriceResponse = try await networking.request(endpoint)
        for response in responseArray {
            print("Symbol: \(response.symbol), Price: \(response.price)")
        }
    } catch {
        print("An error occurred: \(error)")
    }
}




