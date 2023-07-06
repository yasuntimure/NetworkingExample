import Foundation


private let baseURLString = "https://api.binance.com/"
private let API_HOST = "api.binance.com/"

// MARK: - RouterCoordinator

public protocol Endpoint {
    var method: HTTPMethod { get }
    var path: String { get }
    var parameters: Parameters? { get }
    var useToken: Bool { get }
    var encoding: ParameterEncoding { get }
}


// MARK: - ResultCallback typealias

public typealias ResultCallback<T> = (Result<T, NetworkStackError>) -> Void


// MARK: - WebServiceProtocol

public protocol WebServiceProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint, completition: @escaping ResultCallback<T>)
}


// MARK: - NetworkError

public enum NetworkStackError: Error {
    case invalidURL
    case requestFailed
    case responseUnsuccessful
    case invalidData
    case jsonDecodingError
    case notFound
    case badRequest
    case unknownError
}


// MARK: - NetworkManager

public class NetworkManager {
    
    private let baseURL = URL(string: baseURLString)!
    
    // TODO: When user login add your API key here
    private let headers = ["X-MBX-APIKEY": "binance_api_key_here"]

    private var urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }


    func request<T: Decodable>(endpoint: Endpoint, completion: @escaping (Result<T, NetworkError>) -> Void) {

        var request = URLRequest(url: baseURL, timeoutInterval: 10.0)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = headers

        let dataTask = urlSession.dataTask(with: request) { data, response, error in
            if let _ = error {
                OperationQueue.main.addOperation {
                    completion(.failure(.requestFailed))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
                OperationQueue.main.addOperation {
                    print("HTTP Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    completion(.failure(.responseUnsuccessful))
                }
                return
            }

            guard let data = data else {
                OperationQueue.main.addOperation {
                    completion(.failure(.invalidData))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let responseObject = try decoder.decode(T.self, from: data)
                OperationQueue.main.addOperation {
                    completion(.success(responseObject))
                }
            } catch {
                OperationQueue.main.addOperation {
                    completion(.failure(.invalidData))
                }
            }
        }

        dataTask.resume()
    }

}

// MARK: - HTTPMethod

public struct HTTPMethod: RawRepresentable, Equatable, Hashable {
    /// `CONNECT` method.
    public static let connect = HTTPMethod(rawValue: "CONNECT")
    /// `DELETE` method.
    public static let delete = HTTPMethod(rawValue: "DELETE")
    /// `GET` method.
    public static let get = HTTPMethod(rawValue: "GET")
    /// `HEAD` method.
    public static let head = HTTPMethod(rawValue: "HEAD")
    /// `OPTIONS` method.
    public static let options = HTTPMethod(rawValue: "OPTIONS")
    /// `PATCH` method.
    public static let patch = HTTPMethod(rawValue: "PATCH")
    /// `POST` method.
    public static let post = HTTPMethod(rawValue: "POST")
    /// `PUT` method.
    public static let put = HTTPMethod(rawValue: "PUT")
    /// `TRACE` method.
    public static let trace = HTTPMethod(rawValue: "TRACE")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}


/// A dictionary of parameters to apply to a `URLRequest`.
public typealias Parameters = [String: Any]


// MARK: - ParameterEncoding

public enum ParameterEncoding {
    case url
    // Add any other encodings you need.
}


// MARK: - Ticker Endpoint

public enum TickerEndpoint: Endpoint {
    
    case tickerPrice(request: TickerPriceRequest)

    public var method: HTTPMethod {
        switch self {
        case .tickerPrice:
            return .get
        }
    }

    public var path: String {
        switch self {
        case .tickerPrice:
            return "/api/v3/ticker/price"
        }
    }

    public var parameters: Parameters? {
            switch self {
            case .tickerPrice(let request):
                return try? request.asDictionary()
            }
        }

    public var useToken: Bool {
        switch self {
        case .tickerPrice:
            return false
        }
    }

    public var encoding: ParameterEncoding {
        switch self {
        case .tickerPrice:
            return .url
        }
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

public struct TickerPriceRequest: Codable {
    var symbol: String
}

// MARK: - Ticker Price List Response

public struct TickerPriceResponse: Decodable {
    let symbol: String
    let price: String
}






// MARK: - USAGE //////////////////////////////////////////////////////////////////////

let networkManager = NetworkManager()


func getPrice() {
    let priceRequest = PriceRequest(ids: "bitcoin", vsCurrencies: "usd")
    
    networkManager.request(route: SimpleRouter.price(request: priceRequest)) { (result: Result<PriceResponse, NetworkError>) in
        switch result {
        case .success(let priceResponse):
            print("Bitcoin price in USD: \(priceResponse.bitcoin.usd)")
        case .failure(let error):
            print("Failed to get price: \(error)")
        }
    }
}

func getCoinList() {
    networkManager.request(route: CoinsRouter.coinsList) { (result: Result<CoinsListResponse, NetworkError>) in
        switch result {
        case .success(let coinsListResponse):
            print("Coins count: \(coinsListResponse.count)")
        case .failure(let error):
            print("Failed to get price: \(error)")
        }
    }
}

//getPrice()
getCoinList()
