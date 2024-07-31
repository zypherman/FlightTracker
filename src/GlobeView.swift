import Foundation
import SceneKit
import SwiftUI

@available(iOS 16.0, *)
struct GlobeView: View {
    @EnvironmentObject var globe: SwiftGlobe
    @ObservedObject var model: FlightInfoModel
    @State private var userAgreed = false
    @State private var isPortrait = true
    
    var body: some View {
        ZStack {
            SceneView(scene: globe.scene, options: [.allowsCameraControl])
                .edgesIgnoringSafeArea(.all)
        }
        .overlay(FlightInfoOverlay, alignment: .bottom)
        .if(model.connectionError != nil) { // conditional overlay to handle showing refresh button
            $0.overlay(RefreshButton, alignment: .center)
        }
        .onAppear {
            globe.setupInSceneView(globe.gestureHost ?? SCNView(), forARKit: false, enableAutomaticSpin: false)
            globe.setupFlightInfo(with: model.$flightInfo)
        }
        .task {
            await model.refresh()
        }
        .refreshable {
            await model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            if UIDevice.current.orientation.isFlat {
                return // Ignore flat orientations
            }
            updateOrientation()
        }
    }
    
    private func updateOrientation() {
        // Assuming `windowScene` is accessible somehow, passed down or obtained via a UIKit bridge
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            isPortrait = windowScene.interfaceOrientation.isPortrait
        }
    }
    
    var flightInfoOverlayHeight: CGFloat {
        return isPortrait ? 110 : 75
    }
    
    @ViewBuilder
    var FlightInfoOverlay: some View {
        if isPortrait {
            VStack(spacing: 5) {
                if let error = model.connectionError {
                    Text(error.description)
                }
                
                Grid(alignment: .top, horizontalSpacing: 15, verticalSpacing: 8) {
                    GridRow(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text(model.timeAtOrigin)
                                .font(.title3)
                            Text("\(model.originCity)")
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: true, vertical: true)
                        }
                        .padding(.leading, -15)
                        .background(HeightEqualizer())
                        
                        VStack(alignment: .leading) {
                            Text(model.flightNumber)
                                .font(.title3)
                            Text("Flight")
                                .font(.caption)
                        }
                        .background(HeightEqualizer())
                        
                        VStack(alignment: .leading) {
                            Text(model.timeAtDestination)
                                .font(.title3)
                            Text("\(model.destinationCity)")
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .background(HeightEqualizer())
                    }
                    
                    GridRow(alignment: .bottom) {
                        
                        VStack(alignment: .leading) {
                            Text(model.timeToGo)
                                .font(.title3)
                            Text("Time till Landing")
                                .font(.caption)
                            
                        }
                        .background(HeightEqualizer())
                        
                        VStack(alignment: .leading) {
                            Text(model.groundSpeed)
                                .font(.title3)
                            Text("Ground Speed")
                                .font(.caption)
                        }
                        .background(HeightEqualizer())
                        
                        
                        VStack(alignment: .leading) {
                            Text(model.altitude)
                                .font(.title3)
                            Text("Altitude")
                                .font(.caption)
                        }
                        .background(HeightEqualizer())
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: 120)
            .padding(10)
            .background(FlightInfoBackground)
        } else {
            VStack(spacing: 8) {
                if let error = model.connectionError {
                    Text(error.description)
                }
                HStack(alignment: .top, spacing: 15) {
                    VStack(alignment: .leading) {
                        Text(model.timeAtOrigin)
                            .font(.title3)
                        Text("\(model.originCity)")
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(model.flightNumber)
                            .font(.title3)
                        Text("Flight")
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(model.timeAtDestination)
                            .font(.title3)
                        Text("\(model.destinationCity)")
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(model.timeToGo)
                            .font(.title3)
                        Text("Time till Landing")
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(model.groundSpeed)
                            .font(.title3)
                        Text("Ground Speed")
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(model.altitude)
                            .font(.title3)
                        Text("Altitude")
                            .font(.caption)
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: 65)
            .padding(10)
            .background(FlightInfoBackground)
        }
    }

    
    var FlightInfoBackground: some View {
        ZStack {
            Color.black.opacity(0.7)
                    .background(.ultraThinMaterial)
                    .blur(radius: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
    }
    
    var RefreshButton: some View {
        Button(action: { Task { await model.checkConnections() }},
               label: { Image(systemName: "arrow.clockwise.circle.fill").foregroundColor(.white).font(.largeTitle) })
    }
    
}

struct HeightEqualizer: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .frame(height: geometry.size.height)
        }
    }
}

extension View {
    func `if`<Content: View>(_ conditional: Bool, content: (Self) -> Content) -> some View {
        if conditional {
            return AnyView(content(self))
        } else {
            return AnyView(self)
        }
    }
}

struct ContentView: View {
    @StateObject var globe: SwiftGlobe = SwiftGlobe(alignment: .poles)
    @StateObject var flightInfoModel = FlightInfoModel()
    
    var body: some View {
        if #available(iOS 16.0, *) {
            GlobeView(model: flightInfoModel).environmentObject(globe)
        } else {
            // Fallback on earlier versions
            Text("Update the target iOS version")
        }
    }
}

@main
struct GlobeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
