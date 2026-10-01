import Flutter
import UIKit
import AVFoundation
import Speech
import LocalAuthentication
import Security

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var speechEngine: AVAudioEngine?
  private var speechTask: SFSpeechRecognitionTask?
  private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
  private var pendingSpeechResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let secureStorage = FlutterMethodChannel(name: "privacyshield/secure_storage", binaryMessenger: controller.binaryMessenger)
      secureStorage.setMethodCallHandler { call, result in
        let args = call.arguments as? [String: Any] ?? [:]
        let key = args["key"] as? String ?? "access_token"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: Bundle.main.bundleIdentifier ?? "privacyshield",
                                    kSecAttrAccount as String: key]
        switch call.method {
        case "read":
          var item: CFTypeRef?
          var readQuery = query
          readQuery[kSecReturnData as String] = true
          readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
          let status = SecItemCopyMatching(readQuery as CFDictionary, &item)
          if status == errSecItemNotFound { result(nil) }
          else if status != errSecSuccess { result(FlutterError(code: "SECURE_STORAGE_FAILED", message: "Keychain read failed (\(status)).", details: nil)) }
          else if let data = item as? Data { result(String(data: data, encoding: .utf8)) }
          else { result(nil) }
        case "write":
          guard let value = args["value"] as? String else { result(FlutterError(code: "BAD_ARGS", message: "value is required", details: nil)); return }
          SecItemDelete(query as CFDictionary)
          var writeQuery = query
          writeQuery[kSecValueData as String] = Data(value.utf8)
          writeQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
          let status = SecItemAdd(writeQuery as CFDictionary, nil)
          result(status == errSecSuccess ? nil : FlutterError(code: "SECURE_STORAGE_FAILED", message: "Keychain write failed (\(status)).", details: nil))
        case "delete":
          let status = SecItemDelete(query as CFDictionary)
          result(status == errSecSuccess || status == errSecItemNotFound ? nil : FlutterError(code: "SECURE_STORAGE_FAILED", message: "Keychain delete failed (\(status)).", details: nil))
        default: result(FlutterMethodNotImplemented)
        }
      }
      let voice = FlutterMethodChannel(name: "privacyshield/voice", binaryMessenger: controller.binaryMessenger)
      voice.setMethodCallHandler { [weak self] call, result in
        guard call.method == "listen" else { result(FlutterMethodNotImplemented); return }
        self?.listenForSpeech(result: result)
      }
      let biometric = FlutterMethodChannel(name: "privacyshield/biometric", binaryMessenger: controller.binaryMessenger)
      biometric.setMethodCallHandler { call, result in
        guard call.method == "authenticate" else { result(FlutterMethodNotImplemented); return }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock PrivacyShield to view your privacy data") { success, error in
          DispatchQueue.main.async {
            if let error = error, !success {
              let authError = error as? LAError
              if authError?.code == .userCancel || authError?.code == .systemCancel || authError?.code == .appCancel {
                result(false)
              } else {
                result(FlutterError(code: "BIOMETRIC_FAILED", message: error.localizedDescription, details: nil))
              }
            } else {
              result(success)
            }
          }
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func listenForSpeech(result: @escaping FlutterResult) {
    guard pendingSpeechResult == nil else { result(FlutterError(code: "VOICE_BUSY", message: "Speech recognition is already active.", details: nil)); return }
    guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
      result(FlutterError(code: "VOICE_UNAVAILABLE", message: "Speech recognition is unavailable on this device.", details: nil)); return
    }
    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      DispatchQueue.main.async {
        guard let self = self else { result(FlutterError(code: "VOICE_UNAVAILABLE", message: "Speech recognition could not start.", details: nil)); return }
        guard status == .authorized else { result(FlutterError(code: "VOICE_PERMISSION", message: "Allow speech recognition in Settings to use voice input.", details: nil)); return }
        self.beginSpeechRecognition(recognizer: recognizer, result: result)
      }
    }
  }

  private func beginSpeechRecognition(recognizer: SFSpeechRecognizer, result: @escaping FlutterResult) {
    let engine = AVAudioEngine()
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      let input = engine.inputNode
      input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in request.append(buffer) }
      engine.prepare()
      try engine.start()
      speechEngine = engine
      speechRequest = request
      pendingSpeechResult = result
      speechTask = recognizer.recognitionTask(with: request) { [weak self] recognition, error in
        guard let self = self else { return }
        if let text = recognition?.bestTranscription.formattedString, recognition?.isFinal == true {
          self.finishSpeech(text: text)
        } else if let error = error {
          self.finishSpeech(error: FlutterError(code: "VOICE_RECOGNITION_FAILED", message: error.localizedDescription, details: nil))
        }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in self?.finishSpeech(error: FlutterError(code: "VOICE_TIMEOUT", message: "No speech was recognized. Try again.", details: nil)) }
    } catch {
      try? AVAudioSession.sharedInstance().setActive(false)
      result(FlutterError(code: "VOICE_START_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  private func finishSpeech(text: String? = nil, error: FlutterError? = nil) {
    guard let result = pendingSpeechResult else { return }
    pendingSpeechResult = nil
    speechEngine?.stop()
    speechEngine?.inputNode.removeTap(onBus: 0)
    speechRequest?.endAudio()
    speechTask?.cancel()
    speechEngine = nil
    speechRequest = nil
    speechTask = nil
    try? AVAudioSession.sharedInstance().setActive(false)
    if let error = error { result(error) } else { result(text) }
  }
}
