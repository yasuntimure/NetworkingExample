import Foundation

// Binance API = "https://api.binance.com/"


/// A dictionary of parameters to apply to a `URLRequest`.
public typealias Parameters = [String: Any]


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
    var httpMethod: HTTPMethod { get }
    var httpHeaders: HTTPHeaders? { get }
    var request: URLRequest? { get }
    var parameters: Parameters? { get }
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


// MARK: - Ticker Endpoint

public enum TickerEndpoint: Endpoint {
    
    case tickerPrice(request: TickerPriceRequest)
    
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
    
    public var request: URLRequest? {
        switch self {
        case .tickerPrice:
            return request("/api/v3/ticker/price")
        }
    }
    
    public var parameters: Parameters? {
        switch self {
        case .tickerPrice(let request):
            return try? request.asDictionary()
        }
    }
        
    public var task: HTTPTask {
        switch self {
        case .tickerPrice(let request):
            return .requestParameters(parameters: try? request.asDictionary(), encoding: .url)
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


// MARK: - ResultCallback typealias

public typealias ResultCallback<T> = (Result<T, NetworkError>) -> Void


// MARK: - NetworkingProtocol

public protocol NetworkingProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint, completition: @escaping ResultCallback<T>)
}


// MARK: - NetworkManager

public final class Networking: NetworkingProtocol {
    
    private var urlSession: URLSession
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    
    public func request<T: Decodable>(_ endpoint: Endpoint, completition: @escaping ResultCallback<T>) {
        
        guard let request = endpoint.request else {
            return OperationQueue.main.addOperation({ completition(.failure(NetworkError.invalidRequest)) })
        }
                
        let task = urlSession.dataTask(with: request) { (data, response, error) in
            dump(request)
            
            if let error = error {
                return OperationQueue.main.addOperation({ completition(.failure(.requestFailed)) })
            }
            
            guard let data = data else {
                return OperationQueue.main.addOperation({ completition(.failure(.invalidData)) })
            }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                debugPrint(jsonResponse)
            } catch {
                debugPrint("Error", error)
                return OperationQueue.main.addOperation({ completition(.failure(.jsonDecodingError)) })
            }
            
            guard let response = response as? HTTPURLResponse else {
                return OperationQueue.main.addOperation({ completition(.failure(.responseUnsuccessful)) })
            }
            dump(response)
            
            switch response.statusCode {
            case 200...299:
                do {
                    let responseObject = try JSONDecoder().decode(T.self, from: data)
                    OperationQueue.main.addOperation({ completition(.success(responseObject)) })
                } catch {
                    OperationQueue.main.addOperation({ completition(.failure(.jsonDecodingError)) })
                }
            case 400...499:
                OperationQueue.main.addOperation({ completition(.failure(.notFound)) })
            case 500...599:
                OperationQueue.main.addOperation({ completition(.failure(.badRequest)) })
            default:
                OperationQueue.main.addOperation({ completition(.failure(.unknownError)) })
            }
        }
        
        task.resume()
        
    }
    
    
}


// MARK: - Ticker Price Request Model

public struct TickerPriceRequest: Codable {
    var symbol: String?
}

// MARK: - Ticker Price List Response

public struct TickerPriceResponse: Decodable {
    let symbol: String
    let price: String
}


// MARK: - USAGE //////////////////////////////////////////////////////////////////////

let networkManager = Networking()


let tickerPriceRequest = TickerPriceRequest(symbol: nil)

networkManager.request(TickerEndpoint.tickerPrice(request: tickerPriceRequest)) { (result: Result<[TickerPriceResponse], NetworkError>) in
    switch result {
    case .success(let responseArray):
        for response in responseArray {
            print("Symbol: \(response.symbol), Price: \(response.price)")
        }
    case .failure(let error):
        print("An error occurred: \(error)")
    }
}




