//
//  SupabaseClient.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

import Supabase
import Foundation
import UIKit
import AVFoundation
import UniformTypeIdentifiers
import Combine

final class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()

    // ⬇️ Configuration loaded from Config.plist (not committed to git)
    
    private var urlString: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let url = plist["SupabaseURL"] as? String, !url.isEmpty else {
            fatalError("Supabase URL is not configured. Please create Config.plist with SupabaseURL key. See Config.example.plist for reference.")
        }
        return url
    }
    
    private var anonKey: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let key = plist["SupabaseAnonKey"] as? String, !key.isEmpty else {
            fatalError("Supabase anon key is not configured. Please create Config.plist with SupabaseAnonKey key. See Config.example.plist for reference.")
        }
        return key
    }
    
    private var url: URL {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            fatalError("Supabase URL is invalid. Please check Config.plist.")
        }
        return url
    }

    private lazy var client: Supabase.SupabaseClient = {
        guard !anonKey.isEmpty else {
            fatalError("Supabase anon key is not configured. Please check Config.plist.")
        }
        return Supabase.SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }()
    
    // MARK: - Device & Participant State
    
    /// Stable device UUID for this user
    private var deviceUUID: String {
        DeviceIDProvider.shared.deviceUUID
    }
    
    /// Stable user ID for this user
    private var userId: UUID {
        IdentityService.shared.userId
    }
    
    /// Published flag to control whether this participant is active
    @Published var isActiveParticipant: Bool {
        didSet {
            UserDefaults.standard.set(isActiveParticipant, forKey: "isActiveParticipant")
        }
    }
    
    private init() {
        // Load persisted active state, defaulting to true
        isActiveParticipant = UserDefaults.standard.object(forKey: "isActiveParticipant") as? Bool ?? true
    }
    
    /// Helper method to update active state
    func setActive(_ active: Bool) {
        isActiveParticipant = active
    }

    // MARK: - Sleep

    /// Upsert rows into `sleep_samples` using a unique constraint on (user_id, hk_uuid)
    func upsertSleepRows(_ rows: [SleepRow]) async throws {
        guard isActiveParticipant else {
            print("User has opted out; not uploading sleep data.")
            return
        }
        
        try await client.database
            .from("sleep_samples")
            .upsert(rows, onConflict: "user_id,hk_uuid", returning: .minimal)
            .execute()
    }

    // MARK: - Participants

    /// Upsert a participant row using device_uuid as the conflict key
    func upsertParticipant(deviceUUID: String, sonaID: String) async throws {
        guard isActiveParticipant else {
            print("User has opted out; not uploading participant data.")
            return
        }
        
        let participant = Participant(device_uuid: deviceUUID, sona_id: sonaID)

        _ = try await client.database
            .from("participants")
            .upsert(participant, onConflict: "device_uuid")
            .execute()
    }

    // MARK: - Media uploads

    /// Upload arbitrary image bytes (HEIC/JPEG/PNG/WEBP) + record a row
    func uploadImageDataAndRecord(_ data: Data,
                                  ext: String,
                                  mime: String,
                                  userId: UUID) async throws {
        guard isActiveParticipant else {
            print("User has opted out; not uploading media.")
            return
        }
        let filename = "\(UUID().uuidString).\(ext)"
        let path = "\(userId.uuidString)/photos/\(filename)"

        try await client.storage
            .from("user-uploads")
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: mime)
            )

        // Try to decode for dimensions (safe even for HEIC)
        var width: Int? = nil
        var height: Int? = nil
        if let img = UIImage(data: data) {
            width = Int(img.size.width * img.scale)
            height = Int(img.size.height * img.scale)
        }

        let row = MediaRow(
            user_id: userId,
            storage_path: path,
            mime_type: mime,
            bytes: data.count,
            width: width,
            height: height,
            duration_seconds: nil
        )

        try await client.database.from("media_uploads").insert(row).execute()
    }

    /// Upload a JPEG image to Storage and record one row in `public.media_uploads`.
    func uploadImageAndRecord(_ image: UIImage, userId: UUID) async throws {
        guard isActiveParticipant else {
            print("User has opted out; not uploading media.")
            return
        }
        
        guard let data = image.jpegData(compressionQuality: 0.90) else {
            throw NSError(domain: "upload", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "JPEG encoding failed"])
        }

        let path = "\(userId.uuidString)/photos/\(UUID().uuidString).jpg"

        try await client.storage
            .from("user-uploads")
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: "image/jpeg")
            )

        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        let row = MediaRow(
            user_id: userId,
            storage_path: path,
            mime_type: "image/jpeg",
            bytes: data.count,
            width: width,
            height: height,
            duration_seconds: nil
        )

        try await client.database.from("media_uploads").insert(row).execute()
    }

    /// Upload a video file to Storage and record one row in `public.media_uploads`.
    func uploadVideoAndRecord(fileURL: URL, userId: UUID) async throws {
        guard isActiveParticipant else {
            print("User has opted out; not uploading media.")
            return
        }
        
        let data = try Data(contentsOf: fileURL)
        let ext = fileURL.pathExtension.lowercased()
        let mime = UTType(filenameExtension: ext)?.preferredMIMEType ?? "video/quicktime" // default for .mov

        let filename = "\(UUID().uuidString).\(ext.isEmpty ? "mov" : ext)"
        let path = "\(userId.uuidString)/videos/\(filename)"

        try await client.storage
            .from("user-uploads")
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: mime)
            )

        // Extract simple video metadata
        let asset = AVAsset(url: fileURL)
        let duration = asset.duration.seconds

        var width: Int? = nil
        var height: Int? = nil
        if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            width  = Int(abs(size.width))
            height = Int(abs(size.height))
        }

        let row = MediaRow(
            user_id: userId,
            storage_path: path,
            mime_type: mime,
            bytes: data.count,
            width: width,
            height: height,
            duration_seconds: duration
        )

        try await client.database.from("media_uploads").insert(row).execute()
    }
    
    // MARK: - Streak
    
    /// Update streak data in Supabase with the list of completed streak days.
    /// The streakDays array contains date strings in "yyyy-MM-dd" format.
    func updateStreak(streakDays: [String]) async throws {
        guard isActiveParticipant else {
            print("User has opted out; not uploading streak data.")
            return
        }
        
        // Create a row with user_id and the streak days array
        // Assuming a table structure like: user_id (UUID), streak_days (text[] or jsonb), updated_at (timestamp)
        let streakRow = StreakRow(
            user_id: userId,
            streak_days: streakDays,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        // Upsert using user_id as the conflict key
        try await client.database
            .from("user_streaks")
            .upsert(streakRow, onConflict: "user_id")
            .execute()
    }
    
    // MARK: - Opt-Out
    
    /// Delete all rows with this device's data from participants and sleep_samples tables
    func deleteAllUserData() async throws {
        // Delete from participants using device_uuid
        try await client.database
            .from("participants")
            .delete()
            .eq("device_uuid", value: deviceUUID)
            .execute()
        
        // Delete from sleep_samples using user_id
        try await client.database
            .from("sleep_samples")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }
    
    /// Update the participant row for this device_uuid to set is_active = false
    func markUserInactive() async throws {
        try await client.database
            .from("participants")
            .update(["is_active": false])
            .eq("device_uuid", value: deviceUUID)
            .execute()
    }
    
    /// Main opt-out method: either deletes data or marks user inactive
    func optOut(deleteData: Bool, reason: String) async throws {
        // Either delete all data or mark as inactive
        if deleteData {
            try await deleteAllUserData()
        } else {
            try await markUserInactive()
        }
        
        // Update local state and persist
        await MainActor.run {
            setActive(false)
        }
    }
}

// MARK: - DTOs

/// Row shape for `participants`
struct Participant: Encodable {
    let device_uuid: String
    let sona_id: String
}

/// Row shape for `media_uploads`
struct MediaRow: Encodable {
    let user_id: UUID
    let storage_path: String
    let mime_type: String?
    let bytes: Int?
    let width: Int?
    let height: Int?
    let duration_seconds: Double?
}

/// Row shape for `user_streaks`
struct StreakRow: Encodable {
    let user_id: UUID
    let streak_days: [String]  // Array of "yyyy-MM-dd" date strings
    let updated_at: String      // ISO8601 timestamp
}


