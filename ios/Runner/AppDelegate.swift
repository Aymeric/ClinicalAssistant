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
    guard HKHealthStore.isHealthDataAvailable() else {
      result([])
      return
    }

    var clinicalTypes: [HKClinicalType] = []
    if let labType = HKObjectType.clinicalType(forIdentifier: .labResultRecord) {
      clinicalTypes.append(labType)
    }
    if #available(iOS 16.4, *),
       let noteType = HKObjectType.clinicalType(forIdentifier: .clinicalNoteRecord) {
      clinicalTypes.append(noteType)
    }
    if let procedureType = HKObjectType.clinicalType(forIdentifier: .procedureRecord) {
      clinicalTypes.append(procedureType)
    }
    if let conditionType = HKObjectType.clinicalType(forIdentifier: .conditionRecord) {
      clinicalTypes.append(conditionType)
    }
    if let allergyType = HKObjectType.clinicalType(forIdentifier: .allergyRecord) {
      clinicalTypes.append(allergyType)
    }
    if let medicationType = HKObjectType.clinicalType(forIdentifier: .medicationRecord) {
      clinicalTypes.append(medicationType)
    }
    if let immunizationType = HKObjectType.clinicalType(forIdentifier: .immunizationRecord) {
      clinicalTypes.append(immunizationType)
    }
    if let vitalSignType = HKObjectType.clinicalType(forIdentifier: .vitalSignRecord) {
      clinicalTypes.append(vitalSignType)
    }

    guard !clinicalTypes.isEmpty else {
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
    DispatchQueue.global().asyncAfter(deadline: .now() + 15.0) {
      sendResult([])
    }

    healthStore.requestAuthorization(toShare: nil, read: Set(clinicalTypes)) { success, error in
      if let error {
        sendResult([])
        return
      }
      guard success else {
        sendResult([])
        return
      }

      let group = DispatchGroup()
      var allRecords: [[String: Any]] = []
      var seenKeys = Set<String>()
      let recordsLock = NSLock()

      for clinicalType in clinicalTypes {
        group.enter()
        let query = HKSampleQuery(
          sampleType: clinicalType,
          predicate: nil,
          limit: HKObjectQueryNoLimit,
          sortDescriptors: nil
        ) { _, samples, queryError in
          defer { group.leave() }
          guard queryError == nil, let samples = samples as? [HKClinicalRecord] else {
            return
          }

          var extracted: [[String: Any]] = []
          for record in samples {
            guard let data = record.fhirResource?.data,
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let resource = object as? [String: Any]
            else {
              continue
            }
            let resId = (resource["id"] as? String) ?? record.uuid.uuidString
            let resType = (resource["resourceType"] as? String) ?? ""
            let uniqueKey = "\(record.sourceRevision.source.bundleIdentifier):\(resType):\(resId)"

            recordsLock.lock()
            if !seenKeys.contains(uniqueKey) {
              seenKeys.insert(uniqueKey)
              extracted.append([
                "sourceId": record.sourceRevision.source.bundleIdentifier,
                "sourceName": record.sourceRevision.source.name,
                "resource": resource,
              ])
            }
            recordsLock.unlock()
          }

          recordsLock.lock()
          allRecords.append(contentsOf: extracted)
          recordsLock.unlock()
        }
        self.healthStore.execute(query)
      }

      group.notify(queue: .main) {
        sendResult(allRecords)
      }
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
