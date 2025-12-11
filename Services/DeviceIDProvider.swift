//
//  DeviceIDProvider.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import Foundation

final class DeviceIDProvider {
    static let shared = DeviceIDProvider()

    private let key = "device_uuid"
    private(set) var deviceUUID: String

    private init() {
        if let saved = UserDefaults.standard.string(forKey: key) {
            deviceUUID = saved
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: key)
            deviceUUID = newID
        }
    }
}
