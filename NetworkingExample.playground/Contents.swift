import Foundation


private let baseURLString = "https://coingecko.p.rapidapi.com/"
private let API_HOST = "coingecko.p.rapidapi.com"



// MARK: - NetworkError

enum NetworkError: Error {
    case invalidURL
    case requestFailed
    case responseUnsuccessful
    case invalidData
}



// MARK: - NetworkManager

class NetworkManager {
    
    private let baseURL = URL(string: baseURLString)!
    private let headers = [
        "X-RapidAPI-Host": "coingecko.p.rapidapi.com"
    ]

    private var urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func request<T: Decodable>(route: RouterCoordinator, completion: @escaping (Result<T, NetworkError>) -> Void) {
        
        let urlPath = baseURL.appendingPathComponent(route.path)
        
        guard var components = URLComponents(url: urlPath, resolvingAgainstBaseURL: false) else {
            completion(.failure(.invalidURL))
            return
        }

        if route.method == .get, let parameters = route.parameters {
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        }

        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: 10.0)
        request.httpMethod = route.method.rawValue
        request.allHTTPHeaderFields = headers

        // TODO: Handle other HTTP methods and encodings here.

        let dataTask = urlSession.dataTask(with: request) { data, response, error in
            if let _ = error {
                completion(.failure(.requestFailed))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
                print("HTTP Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                completion(.failure(.responseUnsuccessful))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidData))
                return
            }

            do {
                let decoder = JSONDecoder()
                let responseObject = try decoder.decode(T.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(responseObject))
                }
            } catch {
                DispatchQueue.main.async {
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



// MARK: - RouterCoordinator

protocol RouterCoordinator {
    var method: HTTPMethod { get }
    var path: String { get }
    var parameters: Parameters? { get }
    var useToken: Bool { get }
    var encoding: ParameterEncoding { get }
}



// MARK: - Simple Router

public enum MarketDataRouter: RouterCoordinator {
    
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



// MARK: - Coins Router

public enum CoinsRouter: RouterCoordinator {
    
    case coinsList

    public var method: HTTPMethod {
        switch self {
        case .coinsList:
            return .get
        }
    }

    public var path: String {
        switch self {
        case .coinsList:
            return "coins/list"
        }
    }

    public var parameters: Parameters? {
            switch self {
            case .coinsList:
                return nil
            }
        }

    public var useToken: Bool {
        switch self {
        case .coinsList:
            return false
        }
    }

    public var encoding: ParameterEncoding {
        switch self {
        case .coinsList:
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

struct TickerPriceResponse: Decodable {
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
