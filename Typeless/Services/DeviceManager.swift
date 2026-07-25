import Foundation
import AVFoundation
import Combine

// MARK: - Device Manager

@MainActor
final class DeviceManager: ObservableObject {
    @Published var audioDevices: [AudioDeviceModel] = []
    @Published var selectedDeviceIndex = 0
    @Published var hasAvailableDevices = false

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    func refreshDevices() {
        let devices = enumerateAudioDevices()
        let oldCount = audioDevices.count
        audioDevices = devices
        hasAvailableDevices = !devices.isEmpty

        if oldCount != devices.count {
            NotificationCenter.default.post(name: .audioDevicesChanged, object: nil)
        }
    }

    func setSelectedDevice(index: Int) {
        guard index < audioDevices.count else {
            #if DEBUG
            print("⚠️ Invalid device index: \(index), device count: \(audioDevices.count)")
            #endif
            return
        }
        selectedDeviceIndex = index
        UserDefaults.standard.set(index, forKey: "SelectedDeviceIndex")
    }

    func loadSavedDevice() {
        let savedIndex = UserDefaults.standard.integer(forKey: "SelectedDeviceIndex")
        if savedIndex < audioDevices.count {
            setSelectedDevice(index: savedIndex)
        }
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        refreshDevices()
        registerDeviceChangeCallback()
    }

    private func registerDeviceChangeCallback() {
        NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDevices()
        }

        NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDevices()
        }
    }

    private func enumerateAudioDevices() -> [AudioDeviceModel] {
        let devices = AVCaptureDevice.devices(for: .audio)
        return devices.map { device in
            AudioDeviceModel(id: device.uniqueID, name: device.localizedName, uniqueID: device.uniqueID)
        }
    }
}

// MARK: - Notification Names
// Notification.Name extensions are defined in Extensions/Notifications.swift