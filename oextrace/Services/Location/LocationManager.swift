import CoreLocation
import UIKit

class LocationManager {
    
    private init() {}

    static var lastLocation: CLLocation?
    
    private static let locationManager = CLLocationManager()
    
    private static var callbacks = [(CLLocation) -> Void]()
    
    private static var lastTrackingUpdate: Int64 = 0
    
    static func registerCallback(_ call: @escaping (CLLocation) -> Void) {
        if let location = lastLocation {
            call(location)
        } else {
            callbacks.append(call)
        }
    }
    
    static func initialize(_ delegate: CLLocationManagerDelegate) {
        locationManager.delegate = delegate
        locationManager.activityType = .fitness
        
        if let lastPoint = TrackingManager.trackingData.last {
            lastTrackingUpdate = lastPoint.point.tst
        }
    }
    
    static func requestLocationUpdates(_ controller: UIViewController) {
        let authStatus = CLLocationManager.authorizationStatus()
        if authStatus == .notDetermined { // need to always check because of "Allow once" option
            controller.confirm("Would you like to enable location usage now?") {
                requestAuthorization()
            }
        } else if authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse {
            startUpdatingLocation()
        }
    }
    
    static func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    static func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        
        updateBackgroundState()
    }
    
    static func updateBackgroundState() {
        let background = UserSettingsManager.recordTrack
        
        locationManager.allowsBackgroundLocationUpdates = background
        locationManager.pausesLocationUpdatesAutomatically = !background
        
        print("Background updates = \(background)")
    }
    
    static func updateAccuracy(foreground: Bool = true) {
        if foreground {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
    }
    
    static func updateLocation(_ location: CLLocation) {
        lastLocation = location
        
        LocationBordersManager.updateLocationBorders(location)
        
        callbacks.forEach { callback in callback(location) }
        callbacks.removeAll()
        
        if let rootViewController = RootViewController.instance {
            rootViewController.accuracyLabel.isHidden = false
            rootViewController.accuracyLabel.text = "Location accuracy: " +
            "\(Int(location.horizontalAccuracy)) meters"
        }
        
        let now = Date.timestamp()
        if location.horizontalAccuracy > 0 && now - lastTrackingUpdate > TrackingManager.trackingIntervalMs &&
            UserSettingsManager.recordTrack {
            print("Updating tracking location")
            
            let point = RawTrackingPoint(location)
            
            TrackingManager.addTrackingPoint(point)
            
            if let rootViewController = RootViewController.instance {
                rootViewController.updateUserTracks()
            }
            
            lastTrackingUpdate = now
            
            if UserSettingsManager.uploadTrack {
                TracksManager.uploadNewTracks()
            }
        }
    }
        
}
