import Foundation
import AVFoundation

// MARK: - Device Manager

@MainActor
final class DeviceManager: ObservableObject {
    @Published var audioDevices: [AudioDeviceModel] = []
    @Published var selectedDeviceIndex = 0

    init() {
        refreshDevices()
        NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshDevices() }
        }
        NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshDevices() }
        }
    }

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        var devices = discovery.devices.map {
            AudioDeviceModel(id: $0.uniqueID, name: $0.localizedName)
        }
        if devices.isEmpty, let def = AVCaptureDevice.default(for: .audio) {
            devices = [AudioDeviceModel(id: def.uniqueID, name: def.localizedName)]
        }
        audioDevices = devices
        if selectedDeviceIndex >= devices.count {
            selectedDeviceIndex = 0
        }
    }

    var selectedDeviceID: String? {
        guard selectedDeviceIndex < audioDevices.count else { return nil }
        return audioDevices[selectedDeviceIndex].id
    }

    func setSelectedDevice(index: Int) {
        guard index < audioDevices.count else { return }
        selectedDeviceIndex = index
        UserDefaults.standard.set(index, forKey: "SelectedDeviceIndex")
    }
}
