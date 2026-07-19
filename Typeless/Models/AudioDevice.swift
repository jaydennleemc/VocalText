import Foundation
import CoreAudio

// MARK: - Audio Device Model

struct AudioDeviceModel: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    var uniqueID: String = ""

    init(id: AudioDeviceID, name: String, uniqueID: String = "") {
        self.id = id
        self.name = name
        self.uniqueID = uniqueID
    }

    static func == (lhs: AudioDeviceModel, rhs: AudioDeviceModel) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}