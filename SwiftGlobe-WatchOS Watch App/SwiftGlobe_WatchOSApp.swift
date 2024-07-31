//
//  SwiftGlobe_WatchOSApp.swift
//  SwiftGlobe-WatchOS Watch App
//
//  Created by John Anderson on 6/17/24.
//  Copyright © 2024 David Mojdehi. All rights reserved.
//

import SwiftUI

@main
struct SwiftGlobe_WatchOS_Watch_AppApp: App {
    @StateObject private var watchConnectivityManager = WatchConnectivityManager()
    
    var body: some Scene {
        WindowGroup {
            WatchFlightInfoView(inflightInfoModel: watchConnectivityManager)
        }
    }
}
