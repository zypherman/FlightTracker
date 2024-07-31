//
//  SwiftGlobe.swift
//  SwiftGlobe
//
//  Created by David Mojdehi on 4/6/17.
//  Copyright © 2017 David Mojdehi. All rights reserved.
//

import Combine
import Foundation
import SceneKit
#if os(watchOS)
import WatchKit
import SwiftUI
#else
import QuartzCore
// for tvOS siri remote access
import GameController
#endif
import SwiftAstro
import SwiftUI

// In ARKit, 1.0 = 1 meter
let kGlobeRadius = Float(0.5)
let kCameraAltitude = Float(2.2)
let kGlowPointAltitude = Float(kGlobeRadius * 1.001)
let kDistanceToTheSun = Float(300)

let kDefaultCameraFov = CGFloat(40.0)
let kGlowPointWidth = CGFloat(0.025)
let kMinLatLonPerUnity = -0.1
let kMaxLatLonPerUnity = 1.1

// Speed of the default spin:  1 revolution in 60 seconds
let kGlobeDefaultRotationSpeedSeconds = 60.0

// Min & Maximum zoom (in degrees)
let kMinFov = CGFloat(4.0)
let kMaxFov = CGFloat(60.0)

let kAmbientLightIntensity = CGFloat(20.0) // default is 1000!

// kDragWidthInDegrees  -- The amount to rotate the globe on one edge-to-edge swipe (in degrees)
let kDragWidthInDegrees = 180.0

let kTiltOfEarthsAxisInDegrees = 23.5
let kTiltOfEarthsAxisInRadians = (23.5 * Double.pi) / 180.0

let kSkyboxSize = CGFloat(1000.0)
let kTiltOfEclipticFromGalacticPlaneDegrees = 60.2
let kTiltOfEclipticFromGalacticPlaneRadians = Float( (60.2 * Float.pi) / 180.0)


// winter solstice is appx Dec 21, 22, or 23
let kDayOfWinterStolsticeInYear = 356.0
let kDaysInAYear = 365.0

let kAffectedBySpring = 1 << 1

let kSunMarkerName = "sun_marker"
let kOriginMarkerName = "origin_maker"
let kAirplaneMarkerName = "airplane_marker"
let kDestinationMarkerName = "destination_marker"

class SwiftGlobe: ObservableObject {
    
    var gestureHost : SCNView?
    var defaultLatitude: Float?
    var defaultLongitude: Float?
    var scene = SCNScene()
    var camera = SCNCamera()
    var cameraNode = SCNNode()
    var skybox = SCNNode()
    var globe = SCNNode()
    var seasonalTilt = SCNNode()
    var userTiltAndRotation = SCNNode()
    var sun = SCNNode()
    let globeShape = SCNSphere(radius: CGFloat(kGlobeRadius) )
    
    var lastPanLoc : CGPoint?
    var lastFovBeforeZoom : CGFloat?
    var userTiltRadians = Float(0)
    var userRotationRadians = Float(0)
    
    var upDownAlignment : UpDownAlignment
    
    @Published var sunX: Float = kDistanceToTheSun
    @Published var sunY: Float = 0.0
    @Published var sunZ: Float = 0.0
    @Published var sunLong: Float = 0.0
    @Published var sunLat: Float = 0.0
    
    var flightInfoModel: FlightInfoModel?
    
    var updateTimer: Timer?
    
    enum UpDownAlignment {
        case poles
        case dayNightTerminator
    }
    
    private var subscriptions = Set<AnyCancellable>()
    
    func setupFlightInfo(with flightInfoPublisher: some Publisher<FlightInfo?, Never>) {
        flightInfoPublisher
            .receive(on: DispatchQueue.main)
            .sink { flightInfo in
                if let flightInfo {
                    self.update(flightInfo)
                }
            }.store(in: &self.subscriptions)
    }
    
    // Fires every 60 seconds to update the position of the sun
    private func startPositionUpdateTimer() {
        updateTimer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(updateSunPosition), userInfo: nil, repeats: true)
    }
    
    internal init(alignment: UpDownAlignment) {
        upDownAlignment = alignment
        // make the globe
        globeShape.segmentCount = 30
        // the texture revealed by diffuse light sources
        
        // Use a higher resolution image on macOS
        guard let earthMaterial = globeShape.firstMaterial else { assert(false); return }
        earthMaterial.diffuse.contents = "world-large.jpg" //earth-diffuse.jpg"
        
        let emission = SCNMaterialProperty()
        emission.contents = "earth-emissive.jpg"
        earthMaterial.setValue(emission, forKey: "emissionTexture")
        let shaderModifier =    """
                                uniform sampler2D emissionTexture;
                                
                                // how lit-up is this pixel?
                                float3 light = _lightingContribution.diffuse;
                                // compute the 'darkness' of this pixel, too
                                float lum = max(0.0, 1 - 16.0 * (0.2126*light.r + 0.7152*light.g + 0.0722*light.b));
                                // combine the textures, in proportion (regular earth texture & lightPollutionMap, aka emissionTexture)
                                float4 emission = texture2D(emissionTexture, _surface.diffuseTexcoord) * lum * 0.5;
                                _output.color += emission;
                                """
        earthMaterial.shaderModifiers = [.fragment: shaderModifier]
        
        
        
        // the texture revealed by specular light sources
        //earthMaterial.specular.contents = "earth_lights.jpg"
        earthMaterial.specular.contents = "earth-specular.jpg"
        earthMaterial.specular.intensity = 0.2
        //earthMaterial.shininess = 0.1
        
        // the oceans are reflecty & the land is matte
        earthMaterial.metalness.contents = "metalness-1000x500.png"
        earthMaterial.roughness.contents = "roughness-g-w-1000x500.png"
        
        // make the mountains appear taller
        // (gives them shadows from point lights, but doesn't make them stick up beyond the edges)
        earthMaterial.normal.contents = "earth-bump.png"
        earthMaterial.normal.intensity = 0.3
        
        //earthMaterial.reflective.contents = "envmap.jpg"
        //earthMaterial.reflective.intensity = 0.5
        earthMaterial.fresnelExponent = 2
        globe.geometry = globeShape
        
        
        // tilt it on it's axis (23.5 degrees), varied by the actual day of the year
        // (note that children nodes are correctly tilted with the parents coordinate space)
        seasonalTilt.eulerAngles = SCNVector3(SwiftGlobe.computeSeasonalTilt(Date()),0.0, 0.0)
        
        
        //----------------------------------------
        // setup the heirarchy:
        //  rootNode
        //     |
        //     +---userTiltAndRotation
        //           |
        //           +---seasonalTilt
        //                  |
        //                  +globe
        //           +---Sun
        //     +...skybox
        //
        scene.rootNode.addChildHeirarchy( [  userTiltAndRotation,
                                             seasonalTilt,
                                             globe
                                          ])
        // Add the sun above the seasonal tilt! (ie, the season tilt affects the earth, not the sun)
        // NB: user interactivity (on userTiltAndRotation) is also aware of the seasonal tilt, but it must be separate to tilt the earth *and* sun!
        userTiltAndRotation.addChildNode(sun)
        
        //----------------------------------------
        // setup the sun (the light source)
        sun.light = SCNLight()
        sun.light!.type = .directional
        // sun color temp at noon: 5600.
        // White is 6500
        // anything above 5000 is 'daylight'
        sun.light!.castsShadow = false
        sun.light!.temperature = 5500
        sun.light!.intensity = 1200 // default is 1000
        
        updateSunPosition()
        
        if let lat = defaultLatitude, let lon = defaultLongitude {
            focusOnLatLon(lat, lon)
        }
        
        applyUserTiltAndRotation()
        
        startPositionUpdateTimer()
        
        NotificationCenter.default.addObserver(self, selector: #selector(orientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func orientationDidChange(notification: Notification) {
        // Check if the current device orientation is not flat
        if UIDevice.current.orientation.isPortrait || UIDevice.current.orientation.isLandscape {
            resetFOV(UIDevice.current.orientation.isPortrait)
        }
    }
    
    public func addSunMarker() {
        let currentTime = SwiftAstro.Time(date: Date())
        // Get the position of the sun
        let subsolarPoint = SwiftAstro.sun.subsolarPoint(t: currentTime)
        let lat = Float(subsolarPoint.latitude)
        let long = Float(subsolarPoint.longitude)
        
        defaultLatitude = lat
        defaultLongitude = long
        
        if let existingMarker = globe.childNode(withName: kSunMarkerName, recursively: true) {
            existingMarker.removeFromParentNode()
        }
        
        let sunMarker = GlowingMarker(lat: lat, lon: long, altitude: kGlobeRadius, markerZindex: 0, style: .beam(UIColor.clear), name: kSunMarkerName)
        
        self.addMarker(sunMarker, checkForExisting: false)
    }
    
    @objc func updateSunPosition() {
        print("Updating suns position")
        addSunMarker()
        
        // Set the sun node's position
        if let sunMarker = globe.childNode(withName: kSunMarkerName, recursively: true) {
            sun.position = sunMarker.position
        }
        sun.look(at: SCNVector3(0,0,0), up: SCNVector3(0,0,1), localFront: SCNVector3(0,0,-3))
    }
    
    private func update(_ flightInfo: FlightInfo) {
        if let originAirport = flightInfo.originAirport {
            let originMarker = GlowingMarker(lat: originAirport.latitude, lon: originAirport.longitude, altitude: kGlobeRadius, markerZindex: 0, style: .dot(.origin), name: kOriginMarkerName)
            addMarker(originMarker, checkForExisting: true)
        }
        
        if let destinationAirport = flightInfo.destinationAirport {
            let destinationMarker = GlowingMarker(lat: destinationAirport.latitude, lon: destinationAirport.longitude, altitude: kGlobeRadius, markerZindex: 0, style: .dot(.destination), name: kDestinationMarkerName)
            addMarker(destinationMarker, checkForExisting: true)
        }
        
        let airplaneMarker = GlowingMarker(lat: flightInfo.latitude, lon: flightInfo.longitude, altitude: kGlobeRadius, markerZindex: 0, style: .dot(.airplane), name: kAirplaneMarkerName)
        airplaneMarker.addPulseAnimation()
        addMarker(airplaneMarker, checkForExisting: true)
        
        focusOnLatLon(flightInfo.latitude, flightInfo.longitude)
    }
    
    // Calculate how much to tilt the earth for the current season
    // The result is the angle in radianson it's axis (23.5 degrees), varied by the actual day of the year
    // (note that children nodes are correctly tilted with the parents coordinate space)
    public class func computeSeasonalTilt(_ today: Date) -> Double {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = Double( calendar.ordinality(of: .day, in: .year, for: today)! )
        let daysSinceWinterSolstice = remainder(dayOfYear + 10.0, kDaysInAYear)
        let daysSinceWinterSolsticeInRadians = daysSinceWinterSolstice * 2.0 * Double.pi / kDaysInAYear
        let tiltXRadians = -cos( daysSinceWinterSolsticeInRadians) * kTiltOfEarthsAxisInRadians
        return tiltXRadians
    }
    
    public func addMarker(_ marker: GlowingMarker, checkForExisting: Bool) {
        if checkForExisting, 
            let markerName = marker.node.name,
            let existingMarker = globe.childNode(withName: markerName, recursively: true) {
            print("Updating position of maker: \(marker.node.name ?? "")")
            existingMarker.position = marker.node.position
        } else {
            globe.addChildNode(marker.node)
            print("Marker added: \(marker.node.name ?? "")")
        }
    }
    
    func resetFOV(_ isPortrait: Bool) {
        camera.fieldOfView = isPortrait ? kDefaultCameraFov : kDefaultCameraFov - 20
    }
    
    internal func setupInSceneView(_ v: SCNView, forARKit : Bool, enableAutomaticSpin: Bool) {
        v.autoenablesDefaultLighting = false
        v.scene = self.scene
        
        self.gestureHost = v
        
        if forARKit {
            v.allowsCameraControl = true
            skybox.removeFromParentNode()
            
        } else {
            finishNonARSetup(enableAutomaticSpin)
            v.pointOfView = cameraNode
            v.allowsCameraControl = false
            
            let pan = UIPanGestureRecognizer(target: self, action:#selector(SwiftGlobe.onPanGesture(pan:) ) )
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(SwiftGlobe.onPinchGesture(pinch:) ) )
            v.addGestureRecognizer(pan)
            v.addGestureRecognizer(pinch)
        }
    }
    
    private func finishNonARSetup(_ enableAutomaticSpin: Bool) {
        //----------------------------------------
        // add the galaxy skybox
        // we make a custom skybox instead of using scene.background) so we can control the galaxy tilt
        let cubemapTextures = ["eso0932a_front.png","eso0932a_right.png",
                               "eso0932a_back.png", "eso0932a_left.png",
                               "eso0932a_top.png", "eso0932a_bottom.png" ]
        let cubemapMaterials = cubemapTextures.map { (name) -> SCNMaterial in
            let material = SCNMaterial()
            material.diffuse.contents = name
            material.isDoubleSided = true
            material.lightingModel = .constant
            return material
        }
        skybox.geometry = SCNBox(width: kSkyboxSize, height: kSkyboxSize, length: kSkyboxSize, chamferRadius: 0.0)
        skybox.geometry!.materials = cubemapMaterials
        skybox.eulerAngles = SCNVector3(x: kTiltOfEclipticFromGalacticPlaneRadians, y: 0.0, z: 0.0 )
        scene.rootNode.addChildNode(skybox)
        
        // give us some ambient light (to light the rest of the model)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = kAmbientLightIntensity // default is 1000!
        
        //---------------------------------------
        // create and add a camera to the scene
        // set up a 'telephoto' shot (to avoid any fisheye effects)
        // (telephoto: narrow field of view at a long distance
        camera.fieldOfView = kDefaultCameraFov
        camera.zFar = 10000
        cameraNode.position = SCNVector3(x: 0, y: 0, z:  kGlobeRadius + kCameraAltitude )
        cameraNode.constraints = [ SCNLookAtConstraint(target: self.globe) ]
        cameraNode.light = ambientLight
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        
        if enableAutomaticSpin {
            let spinRotation = SCNAction.rotate(by: 2 * .pi, around: SCNVector3(0, 1, 0), duration: kGlobeDefaultRotationSpeedSeconds)
            let spinAction = SCNAction.repeatForever(spinRotation)
            globe.runAction(spinAction)
        }
    }
    
    private func addPanGestures() {}
    
    @objc fileprivate func onPanGesture(pan : UIPanGestureRecognizer) {
        // we get here on a tap!
        guard let sceneView = pan.view else { return }
        let loc = pan.location(in: sceneView)
        
        if pan.state == .began {
            handlePanBegan(loc)
        } else {
            guard pan.numberOfTouches == 1 else { return }
            self.handlePanCommon(loc, viewSize: sceneView.frame.size)
        }
    }
    
    @objc fileprivate func onPinchGesture(pinch: UIPinchGestureRecognizer){
        // update the fov of the camera
        if pinch.state == .began {
            self.lastFovBeforeZoom = self.camera.fieldOfView
        } else {
            if let lastFov = self.lastFovBeforeZoom {
                var newFov = lastFov / CGFloat(pinch.scale)
                if newFov < kMinFov {
                    newFov = kMinFov
                } else if newFov > kMaxFov {
                    newFov = kMaxFov
                }
                //print("new zoom fov: \(newFov)")
                self.camera.fieldOfView =  newFov
            }
        }
    }
    
    // A simple zoom interface (for the watch)
    public var zoomFov : CGFloat {
        get {
            return self.camera.fieldOfView
        }
        set(newFov) {
            if newFov < kMinFov {
                self.camera.fieldOfView = kMinFov
            } else if newFov > kMaxFov {
                self.camera.fieldOfView = kMaxFov
            } else {
                self.camera.fieldOfView = newFov
            }
        }
    }
    
    public func handlePanBegan(_ loc: CGPoint) {
        lastPanLoc = loc
    }
    
    public func handlePanCommon(_ loc: CGPoint, viewSize: CGSize) {
        guard let lastPanLoc = lastPanLoc else { return }
        
        // measue the movement difference
        let delta = CGSize(width: (lastPanLoc.x - loc.x) / viewSize.width, height: (lastPanLoc.y - loc.y) / viewSize.height )
        
        handlePan(deltaPerUnity: delta)
        
        self.lastPanLoc = loc
    }
    public func handlePan(deltaPerUnity delta: CGSize) {
        //  DeltaX = amount of rotation to apply (about the world axis)
        //  DelyaY = amount of tilt to apply (to the axis itself)
        if delta.width != 0.0 || delta.height != 0.0 {
            
            // as the user zooms in (smaller fieldOfView value), the finger travel is reduced
            let fovProportion = (self.camera.fieldOfView - kMinFov) / (kMaxFov - kMinFov)
            let fovProportionRadians = Float(fovProportion * CGFloat(kDragWidthInDegrees) ) * ( .pi / 180)
            let rotationAboutAxis = Float(delta.width) * fovProportionRadians
            let tiltOfAxisItself = Float(delta.height) * fovProportionRadians
            
            // update the user values...
            userTiltRadians -= tiltOfAxisItself
            userRotationRadians -= rotationAboutAxis
            
            applyUserTiltAndRotation()
        }
    }
    
    public func focusOnLatLon(_ lat: Float, _ lon: Float) {
        globe.removeAllActions()
        
        let latRadians = lat / 180.0 * .pi
        let lonRadians = lon / 180.0 * .pi
        
        // Set user rotation
        userTiltRadians = latRadians
        userRotationRadians = -lonRadians
        
        applyUserTiltAndRotation()
        
        // Adjust the camera's position to look at the target point
        let targetPosition = SCNVector3(
            x: kGlobeRadius * cos(latRadians) * cos(lonRadians),
            y: kGlobeRadius * cos(latRadians) * sin(lonRadians),
            z: kGlobeRadius * sin(latRadians)
        )
        
        let cameraLookAtConstraint = SCNLookAtConstraint(target: globe)
        cameraLookAtConstraint.isGimbalLockEnabled = true
        cameraNode.constraints = [cameraLookAtConstraint]
        
        // Position camera to face the target point on the globe
        cameraNode.position = SCNVector3(
            x: targetPosition.x * 1.5,
            y: targetPosition.y * 1.5,
            z: targetPosition.z + kCameraAltitude
        )
        
        let axisAngle = SCNVector4(0, 1, 0, 0 )
        let spinTo = SCNAction.rotate(toAxisAngle: axisAngle, duration: 0.1)
        globe.runAction(spinTo)
    }
    
    internal func applyUserTiltAndRotation() {
        // .. and recompute the interactivity matrix
        var matrix = SCNMatrix4Identity
        // now apply the user tilt
        matrix = SCNMatrix4RotateF(matrix, userTiltRadians, 1.0, 0.0, 0.0)
        
        let seasonalTilt = -Float(SwiftGlobe.computeSeasonalTilt(Date()))
        switch upDownAlignment {
        case .poles:
            // first, apply the rotation (along the Y axis)
            matrix = SCNMatrix4RotateF(matrix, userRotationRadians, 0.0, 1.0, 0.0)
            // now tilt it (about the X axis) for the seasonal rotation
            matrix = SCNMatrix4RotateF(matrix, seasonalTilt, 1.0, 0.0, 0.0)
        case .dayNightTerminator:
            // now tilt it (about the X axis) for the seasonal rotation
            matrix = SCNMatrix4RotateF(matrix, seasonalTilt, 1.0, 0.0, 0.0)
            // first, apply the rotation (along the Y axis)
            matrix = SCNMatrix4RotateF(matrix, userRotationRadians, 0.0, 1.0, 0.0)
        }
        userTiltAndRotation.transform = matrix
    }
}

func SCNMatrix4RotateF(_ src: SCNMatrix4, _ angle : Float, _ x : Float, _ y : Float, _ z : Float) -> SCNMatrix4 {
    return SCNMatrix4Rotate(src, angle, x, y, z)
}

extension SCNNode {
    // Add a list of nodes as children of eachother
    func addChildHeirarchy(_ nodes: [SCNNode]) {
        // must have at least one to connect!
        if nodes.count < 1 {
            return
        }
        var currentNode = self
        for node in nodes {
            currentNode.addChildNode(node)
            currentNode = node
        }
    }
}
