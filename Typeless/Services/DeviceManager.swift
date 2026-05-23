import Foundation
import CoreAudio
import Combine

// MARK: - Device Manager

@MainActor
final class DeviceManager: ObservableObject {
    @Published var audioDevices: [AudioDeviceModel] = []
    @Published var selectedDeviceIndex = 0
    @Published var hasAvailableDevices = false

    private var selectedDeviceID: AudioDeviceID?
    private var monitoringTimer: Timer?

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    deinit {
        // Timer invalidation is safe from any thread
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    // MARK: - Public Methods

    func refreshDevices() {
        let devices = getAvailableAudioDevicesSync()
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
        selectedDeviceID = audioDevices[index].id
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
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.Device.monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }
    }

    private func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func getAvailableAudioDevicesSync() -> [AudioDeviceModel] {
        var devices: [AudioDeviceModel] = []

        var deviceCount = UInt32(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize = UInt32(0)
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)
        guard status == noErr else { return devices }

        deviceCount = propertySize / UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceIDs = [AudioDeviceID](repeating: 0, count: Int(deviceCount))
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs)
        guard status == noErr else { return devices }

        for deviceID in deviceIDs {
            var streamCount = UInt32(0)
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            propertySize = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &propertySize)
            guard status == noErr else { continue }

            streamCount = propertySize / UInt32(MemoryLayout<AudioObjectID>.size)
            if streamCount > 0 {
                let deviceName = getDeviceName(deviceID: deviceID)
                if deviceName != NSLocalizedString("status.device.unknown", comment: "Unknown device") && !deviceName.isEmpty {
                    devices.append(AudioDeviceModel(id: deviceID, name: deviceName))
                }
            }
        }

        return devices
    }

    private func getDeviceName(deviceID: AudioDeviceID) -> String {
        var propertySize = UInt32(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propertySize)
        guard status == noErr else { return NSLocalizedString("status.device.unknown", comment: "Unknown device") }

        var deviceNameCFString: CFString?
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &deviceNameCFString)
        if status == noErr, let name = deviceNameCFString {
            return name as String
        }
        return NSLocalizedString("status.device.unknown", comment: "Unknown device")
    }
}

// MARK: - Notification Names

// Notification names are defined in MainView.swift