import Flutter
import HealthKit
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    URLCache.shared = URLCache(
      memoryCapacity: 0,
      diskCapacity: 0,
      diskPath: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocalVaultDirectoryPlugin") {
      LocalVaultDirectoryPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppleClinicalRecordsPlugin") {
      AppleClinicalRecordsPlugin.register(with: registrar)
    }
  }
}

private final class AppleClinicalRecordsPlugin: NSObject, FlutterPlugin {
  private let healthStore = HKHealthStore()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "clinical_assistant/apple_clinical_records",
      binaryMessenger: registrar.messenger()
    )
    let instance = AppleClinicalRecordsPlugin()
    channel.setMethodCallHandler { call, result in
      guard call.method == "importLabRecords" else {
        result(FlutterMethodNotImplemented)
        return
      }
      instance.importLabRecords(result: result)
    }
  }

  private func importLabRecords(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let clinicalType = HKObjectType.clinicalType(forIdentifier: .labResultRecord)
    else {
      result([])
      return
    }

    var hasResponded = false
    let lock = NSLock()
    func sendResult(_ res: Any?) {
      lock.lock()
      defer { lock.unlock() }
      guard !hasResponded else { return }
      hasResponded = true
      DispatchQueue.main.async {
        result(res)
      }
    }

    // Safety timeout: if HealthKit authorization prompt or query hangs, return empty results
    DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
      sendResult([])
    }

    healthStore.requestAuthorization(toShare: nil, read: [clinicalType]) { success, error in
      if let error {
        sendResult([])
        return
      }
      guard success else {
        sendResult([])
        return
      }

      let query = HKSampleQuery(
        sampleType: clinicalType,
        predicate: nil,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, queryError in
        if let queryError {
          sendResult([])
          return
        }

        let records = (samples as? [HKClinicalRecord] ?? []).compactMap { record
          -> [String: Any]? in
          guard let data = record.fhirResource?.data,
                let object = try? JSONSerialization.jsonObject(with: data),
                let resource = object as? [String: Any]
          else {
            return nil
          }
          return [
            "sourceId": record.sourceRevision.source.bundleIdentifier,
            "sourceName": record.sourceRevision.source.name,
            "resource": resource,
          ]
        }
        sendResult(records)
      }
      self.healthStore.execute(query)
    }
  }
}

private final class LocalVaultDirectoryPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "clinical_assistant/local_data",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "vaultDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }

      do {
        let fileManager = FileManager.default
        let supportDirectory = try fileManager.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        var vaultDirectory = supportDirectory.appendingPathComponent(
          "ClinicalAssistantVault",
          isDirectory: true
        )
        try fileManager.createDirectory(
          at: vaultDirectory,
          withIntermediateDirectories: true
        )
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try vaultDirectory.setResourceValues(resourceValues)
        try fileManager.setAttributes(
          [.protectionKey: FileProtectionType.complete],
          ofItemAtPath: vaultDirectory.path
        )
        result(vaultDirectory.path)
      } catch {
        result(
          FlutterError(
            code: "vault_directory",
            message: "Could not prepare the protected local vault directory.",
            details: error.localizedDescription
          )
        )
      }
    }
  }
}
