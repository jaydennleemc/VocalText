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
    private var deviceListener: AudioObjectPropertyListenerBlock?

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    deinit {
        // Inline cleanup: deinit is not @MainActor-isolated so we cannot call stopMonitoring()
        if let listener = deviceListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                nil,
                listener
            )
        }
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
        registerDeviceChangeCallback()
    }

    private func stopMonitoring() {
        if let listener = deviceListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                nil,
                listener
            )
            deviceListener = nil
        }
    }

    private func registerDeviceChangeCallback() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let listener: AudioObjectPropertyListenerBlock = { [weak self] inCount, inAddresses in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil,
            listener
        )

        if status == noErr {
            deviceListener = listener
        } else {
            #if DEBUG
            print("⚠️ Failed to register CoreAudio device callback, status: \(status)")
            #endif
        }
    }

    private func enumerateAudioDevices() -> [AudioDeviceModel] {
        var devices: [AudioDeviceModel] = []

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize = UInt32(0)
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)
        guard status == noErr else { return devices }

        let deviceCount = propertySize / UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceIDs = [AudioDeviceID](repeating: 0, count: Int(deviceCount))
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs)
        guard status == noErr else { return devices }

        for deviceID in deviceIDs {
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            propertySize = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &propertySize)
            guard status == noErr else { continue }

            let streamCount = propertySize / UInt32(MemoryLayout<AudioObjectID>.size)
            if streamCount > 0 {
                let deviceName = getDeviceName(deviceID: deviceID)
                if !deviceName.isEmpty {
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

        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propertySize) == noErr else {
            return NSLocalizedString("status.device.unknown", comment: "Unknown device")
        }

        var deviceNameCFString: CFString?
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &deviceNameCFString)
        if status == noErr, let name = deviceNameCFString {
            return name as String
        }
        return NSLocalizedString("status.device.unknown", comment: "Unknown device")
    }
}

// MARK: - Notification Names
// Notification.Name extensions are defined in Extensions/Notifications.swift