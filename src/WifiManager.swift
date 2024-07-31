import Combine
import CoreLocation
import Foundation
import NetworkExtension
import SystemConfiguration.CaptiveNetwork

class WiFiManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var ssid: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }

    // TODO check this against physical device
    // Simulator devices won't have any data return for this logic
    func getCurrentWiFiSSID() -> String? {
#if targetEnvironment(simulator)
        return "Test"
#else
        guard let interface = CNCopySupportedInterfaces() as? [String] else { return nil }
        for iface in interface {
            guard let info = CNCopyCurrentNetworkInfo(iface as CFString) as NSDictionary? else { continue }
            if let ssid = info[kCNNetworkInfoKeySSID as String] as? String {
                return ssid
            }
        }
        return nil
#endif
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            ssid = getCurrentWiFiSSID()
        }
    }
}
