import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    var mapsApiKey = ""
    let envAssetKey = FlutterDartProject.lookupKey(forAsset: ".env")
    var envPath = Bundle.main.path(forResource: envAssetKey, ofType: nil)
    
    // Attempt 2: Check inside App.framework (required for use_frameworks! builds)
    if envPath == nil {
        if let frameworkURL = Bundle.main.privateFrameworksURL?.appendingPathComponent("App.framework"),
           let appBundle = Bundle(url: frameworkURL) {
            envPath = appBundle.path(forResource: ".env", ofType: nil, inDirectory: "flutter_assets")
        }
    }
    
    // Attempt 3: Check with split path in main bundle
    if envPath == nil && envAssetKey.contains("/") {
        let components = envAssetKey.components(separatedBy: "/")
        if let fileName = components.last {
            let directoryName = components.dropLast().joined(separator: "/")
            envPath = Bundle.main.path(forResource: fileName, ofType: nil, inDirectory: directoryName)
        }
    }
    
    if let path = envPath {
        NSLog("AppDelegate: Found .env file at path: \(path)")
        if let envString = try? String(contentsOfFile: path) {
            var genericKey = ""
            var iosKey = ""
            for line in envString.split(separator: "\n") {
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let val = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if key == "MAPS_API_KEY_IOS" {
                        iosKey = val
                    } else if key == "MAPS_API_KEY" {
                        genericKey = val
                    }
                }
            }
            mapsApiKey = !iosKey.isEmpty ? iosKey : genericKey
        } else {
            NSLog("AppDelegate: ERROR - Could not read contents of .env file")
        }
    } else {
        NSLog("AppDelegate: ERROR - Could not locate .env file path in bundle resources")
    }
    
    if !mapsApiKey.isEmpty {
        GMSServices.provideAPIKey(mapsApiKey)
        NSLog("Google Maps API Key successfully loaded from .env")
    } else {
        NSLog("WARNING: Google Maps API Key not found in .env or is empty")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
