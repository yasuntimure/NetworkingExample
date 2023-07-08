# Networking Example

## Implementation with Binance API

This project is a Swift implementation of the Binance API, encapsulated into a simple and easy-to-use networking layer.

## Description

The main purpose of the project is to provide a simple, lightweight, and efficient wrapper to interact with the Binance Ticker API. It supports getting the latest price for a specific symbol or all symbols.

## Project Structure

The project is structured in a modular way to ensure reusability and simplicity. The project is divided into several components:

- **Endpoint**: This protocol defines the essential elements of a request such as `HTTPMethod`, `HTTPHeaders`, request `URL`, `Parameters`, etc.

- **NetworkingProtocol**: This protocol defines the `request` method, which initiates the HTTP request.

- **Networking**: This class conforms to the `NetworkingProtocol` and manages all the HTTP requests. It sends requests, handles responses and errors, and decodes JSON response into Swift objects.

- **NetworkError**: This enum represents potential errors that may occur during network communication.

- **TickerEndpoint**: This enum conforms to the `Endpoint` protocol and is responsible for specifying the endpoints related to the Binance Ticker API.

- **TickerPriceRequest** & **TickerPriceResponse**: These structs represent the request and response models for the Binance Ticker API.

## Usage

```swift
let networkManager = Networking()
let tickerPriceRequest = TickerPriceRequest(symbol: nil)

networkManager.request(TickerEndpoint.tickerPrice(request: tickerPriceRequest)) { (result: Result<TickerPriceResponse, NetworkError>) in
    switch result {
    case .success(let responseArray):
        for response in responseArray {
            print("Symbol: \(response.symbol), Price: \(response.price)")
        }
    case .failure(let error):
        print("An error occurred: \(error)")
    }
}
```

In this example, the `networkManager` sends a request to the `TickerEndpoint.tickerPrice` endpoint with `TickerPriceRequest`. The result of the request is handled in a completion block, which provides either the response array (`TickerPriceResponse`) or an error (`NetworkError`).

## Dependencies

The project does not depend on any third-party libraries.

## Author

Eyup Yasuntimur
