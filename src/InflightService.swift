import Combine
import Foundation
import NetworkExtension

enum InflightServiceError: Error {
    case wifiSSIDError
    case serviceDown
    case fetchFlightDataError
    case airportDataError
    
    var description: String {
        switch self {
        case .wifiSSIDError:
            return "Please ensure you are connected to inflight wifi"
        case .fetchFlightDataError:
            return "Error retrieving flight information, please refresh"
        case .serviceDown:
            return "Inflight Wifif Error, please refresh"
        case .airportDataError:
            return "Airport data was unable to be loaded"
        }
    }
}

class InflightService: ObservableObject {
    private var airports: [Airport] = []
    private var activeUrl: URL?
    private var session: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30 // URL Session timeout
        return URLSession(configuration: configuration)
    }
    
    let validSSIDs = ["aainflight.com", "Test"]
    
    let urls = [
//        URL(string: "https://www.aainflight.com/api/v1/connectivity/viasat/flight")!
        URL(string: "https://kertob.americanplus.us/gtgn/flight2.php")!
    ]
    
    init() {
        loadAirports()
    }
    
    func checkForValidSSID() throws -> Bool {
        let wifiManager = WiFiManager()
        if let wifiSSID = wifiManager.getCurrentWiFiSSID(), validSSIDs.contains(wifiSSID) {
            return true
        } else {
            throw InflightServiceError.wifiSSIDError
        }
    }
    
    // load airport data from file
    private func loadAirports() {
        if let path = Bundle.main.path(forResource: "airports", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let decoder = JSONDecoder()
                airports = try decoder.decode([Airport].self, from: data)
                return
            } catch {
                print("Failed to load airport data: \(error.localizedDescription)")
            }
        } else {
            print("Could not find airports.json file")
        }
        airports = []
    }

    // check which URL is valid for FlightInfo data
    func checkForActiveUrl() async throws -> Bool {
        for url in urls {
            if let (_, response) = try? await session.data(from: url) {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // valid url found
                    print("valid url found: \(url)")
                    activeUrl = url
                    return true
                }
            }
        }
        
        // if we go through all our URL's and no valid url is found, throw an error
        throw InflightServiceError.serviceDown
    }
    
    func fetchFlightInfo() async throws -> FlightInfo? {
        guard let activeUrl else { return nil }
        if airports.isEmpty {
            throw InflightServiceError.airportDataError
        }
        
        do {
            let (data, response) = try await session.data(from: activeUrl)
            
            // Check for 200 status code
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Failed to fetch data from: \(activeUrl.absoluteString)")
                throw InflightServiceError.fetchFlightDataError
            }
            
            // Decode the JSON data into FlightInfo
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            var flightInfo: FlightInfo
            
            // future TODO, add a swiftier way to hold both the urls in an easier to distinguish way
            if activeUrl.absoluteString.contains("flight1.php") {
                let longFlightInfo = try decoder.decode(LongerFlightInfo.self, from: data)
                // transform into FlightInfo
                flightInfo = longFlightInfo.transformInfoFlightInfo()
            } else {
                flightInfo = try decoder.decode(FlightInfo.self, from: data)
            }
            
            // configure airport data
            // not 100% to use ICAO vs IATA
            flightInfo.originAirport = airports.first(where: { $0.icao == flightInfo.origin })
            flightInfo.destinationAirport = airports.first(where: { ($0.icao == flightInfo.destination)})
            
            return flightInfo
        } catch {
            print("error: \(error.localizedDescription)")
            throw InflightServiceError.fetchFlightDataError
        }
    }
}
