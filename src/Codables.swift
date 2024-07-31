import Foundation

public struct Airport: Codable, Sendable {
    let iata, country, icao: String
    var city: String
    let latitude, longitude: Float
    let altitude: Double
    let tz: String

    enum CodingKeys: String, CodingKey {
        case city = "City"
        case country = "Country"
        case iata = "IATA"
        case icao = "ICAO"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case altitude = "Altitude"
        case tz = "TZ"
    }
}

public struct FlightInfo: Decodable {
    let timestamp: Date
    let eta: Double?
    let flightDuration: Int
    let flightNumber: String
    let latitude, longitude: Float
    let noseID: String?
    let paState: String?
    let vehicleID, destination, origin: String
    let flightID: String?
    let airspeed, airTemperature, altitude, distanceToGo: Double?
    let doorState: String
    let groundspeed: Double
    let heading, timeToGo: Int
    let wheelWeightState: String
    
    var destinationAirport: Airport? = nil
    var originAirport: Airport? = nil
    
    enum CodingKeys: String, CodingKey {
        case timestamp, eta, flightDuration, flightNumber, latitude, longitude
        case noseID = "noseId"
        case paState
        case vehicleID = "vehicleId"
        case destination, origin
        case flightID = "flightId"
        case airspeed, airTemperature, altitude, distanceToGo, doorState, groundspeed, heading, timeToGo, wheelWeightState
    }
    
}

extension DateFormatter {
  static let iso8601Full: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}

// MARK: - FlightInfo
public struct LongerFlightInfo: Codable, Sendable {
    let response: Response

    enum CodingKeys: String, CodingKey {
        case response = "Response"
    }
    
    func transformInfoFlightInfo() -> FlightInfo {
        let flightInfo = response.flightInfo
        return FlightInfo(timestamp: flightInfo.utcTimeDate ?? Date.now, eta: nil, flightDuration: 0, flightNumber: flightInfo.flightNumberInfo, latitude: flightInfo.latitude, longitude: flightInfo.longitude, noseID: nil, paState: nil, vehicleID: flightInfo.tailNumber, destination: flightInfo.destinationAirportCode, origin: flightInfo.departureAirportCode, flightID: nil, airspeed: nil, airTemperature: 0, altitude: flightInfo.altitude, distanceToGo: 0, doorState: "", groundspeed: flightInfo.hspeed, heading: 0, timeToGo: response.systemInfo.timeToLand, wheelWeightState: "")
    }
}

// MARK: - Response
public struct Response: Codable, Sendable {
    let status: Int
    let flightInfo: FlightInfoClass
    let gogoFacts: String
    let serviceInfo: ServiceInfo
    let ipAddress, macAddress: String
    let systemInfo: SystemInfo
    let deviceIid: String

    enum CodingKeys: String, CodingKey {
        case status, flightInfo, gogoFacts, serviceInfo, ipAddress, macAddress, systemInfo
        case deviceIid = "device_iid"
    }
}

// MARK: - FlightInfoClass
public struct FlightInfoClass: Codable, Sendable {
    let logo, airlineName: String?
    let airlineCode: String
    let airlineCodeIata: String?
    let tailNumber, flightNumberInfo: String
    let flightNumberAlpha, flightNumberNumeric: String?
    let departureAirportCode, destinationAirportCode, departureAirportCodeIata, destinationAirportCodeIata: String
    let departureAirportLatitude, destinationAirportLatitude, departureAirportLongitude, destinationAirportLongitude: Double
    let origin, destination, departureCity, destinationCity: String?
    let expectedArrival: String
    let departureTime: String?
    let abpVersion, acpuVersion: String
    let videoService: Bool
    let latitude, longitude: Float
    let altitude: Double
    let localTime: String?
    let utcTime: String
    let destinationTimeZoneOffset: Int
    let hspeed, vspeed: Double
    
    var utcTimeDate: Date? {
        guard let utcTimeDate = DateFormatter.iso8601Full.date(from: utcTime) else {
            return nil
        }
        return utcTimeDate
    }
}

// MARK: - ServiceInfo
public struct ServiceInfo: Codable, Sendable {
    let service: String
    let remaining: Int
    let quality, productCode: String?
    let alerts: [String]
}

// MARK: - SystemInfo
public struct SystemInfo: Codable, Sendable {
    let wapType, systemType, arincEnabled: String
    let aboveGndLevel, aboveSeaLevel, flightPhase: String
    let horizontalVelocity, verticalVelocity: String
    let flightNo: String
    let timeToLand: Int
    let paxSSIDStatus, casSSIDStatus, countryCode, airportCode: String
    let linkState, linkType, tunnelState, tunnelType: String
    let ifcPaxServiceState, ifcCasServiceState, currentLinkStatusCode, currentLinkStatusDescription: String
    let noSubscribedUsers, aircraftType: String

    enum CodingKeys: String, CodingKey {
        case wapType, systemType, arincEnabled, horizontalVelocity, verticalVelocity, aboveGndLevel, aboveSeaLevel, flightPhase, flightNo, timeToLand
        case paxSSIDStatus = "paxSsidStatus"
        case casSSIDStatus = "casSsidStatus"
        case countryCode, airportCode, linkState, linkType, tunnelState, tunnelType, ifcPaxServiceState, ifcCasServiceState, currentLinkStatusCode, currentLinkStatusDescription, noSubscribedUsers, aircraftType
    }
}
