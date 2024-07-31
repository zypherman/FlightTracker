import Foundation
import SwiftUI
import WatchConnectivity

class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var serviceError: String?
    @Published var timeAtOrigin: String = "N/A"
    @Published var originCity: String = "Origin"
    @Published var timeAtDestination: String = "N/A"
    @Published var destinationCity: String = "Destination"
    @Published var timeToGo: String = "N/A"
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle activation state changes
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if !message.isEmpty {
            DispatchQueue.main.async {
                if let error = message["serviceError"] as? String, error != "" {
                    self.serviceError = error
                } else {
                    self.serviceError = nil
                }
                
                if let updatedTimeAtOrigin = message["timeAtOrigin"] as? String {
                    self.timeAtOrigin = updatedTimeAtOrigin
                }
                
                if let updatedOriginCity = message["origin"] as? String {
                    self.originCity = updatedOriginCity
                }
                
                if let updatedTimeAtDestination = message["timeAtDestination"] as? String {
                    self.timeAtDestination = updatedTimeAtDestination
                }
                
                if let updatedDestinationCity = message["destination"] as? String {
                    self.destinationCity = updatedDestinationCity
                }
                
                if let updatedTimeTogo = message["timeToGo"] as? String {
                    self.timeToGo = updatedTimeTogo
                }
            }
        }
    }
}
