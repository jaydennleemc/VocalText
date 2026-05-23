import Foundation
import CoreAudio

// MARK: - Audio Device Model

struct AudioDeviceModel: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String

    static func == (lhs: AudioDeviceModel, rhs: AudioDeviceModel) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}