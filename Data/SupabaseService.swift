//
//  SupabaseService.swift
//  Inoxity
//
//  Created by Rachael Kee on 11/9/25.
//

// Importing dependencies
import Supabase
import Foundation
import UIKit
import AVFoundation
import UniformTypeIdentifiers
import Combine

final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    // MARK: Config
    private var configPlist: NSDictionary {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            fatalError("Config.plist missing or unreadable. Please add it to the app target.")
        }
        return plist
    }
    
    private var urlString: String {
        guard let url = configPlist["SupabaseURL"] as? String, !url.isEmpty else {
            fatalError("SupabaseURL is not configured in Config.plist.")
        }
        return url
    }
    
    private var anonKey: String {
        guard let key = configPlist["SupabaseAnonKey"] as? String, !key.isEmpty else {
            fatalError("SupabaseAnonKey is not configured in Config.plist.")
        }
        return key
    }
    
    private var url: URL {
        guard let url = URL(string: urlString) else {
            fatalError("Supabase URL is invalid. Please check Config.plist.")
        }
        return url
    }
    
    // MARK: Client
    private lazy var client: SupabaseClient = {
        let options = SupabaseClientOptions(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
        
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: options
        )
    }()
    
    // MARK: Auth bootstrap (Anonymous)
    @Published private(set) var authedUserId: UUID?

    @MainActor
    func ensureAnonymousSession() async throws {
        if let session = try? await client.auth.session {
            if session.isExpired {
                let refreshed = try await client.auth.refreshSession()
                authedUserId = refreshed.user.id
            } else {
                authedUserId = session.user.id
            }
            return
        }

        let resp = try await client.auth.signInAnonymously()
        authedUserId = resp.user.id
    }

    @MainActor
    private func requireAuthedUserId() async throws -> UUID {
        try await ensureAnonymousSession()
        guard let id = authedUserId else {
            throw NSError(domain: "SupabaseService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Missing Supabase authed user id"])
        }
        return id
    }

    @MainActor
    func makeObjectPath() async throws -> String {
        let uid = try await requireAuthedUserId()
        return "\(uid.uuidString)/photos/\(UUID().uuidString).png"
    }
    
    // MARK: Participant state
    @Published var isActiveParticipant: Bool {
        didSet { UserDefaults.standard.set(isActiveParticipant, forKey: "isActiveParticipant") }
    }
    
    private init() {
        isActiveParticipant = UserDefaults.standard.object(forKey: "isActiveParticipant") as? Bool ?? true
    }
    
    func setActive(_ active: Bool) { isActiveParticipant = active }
    
    // MARK: Sleep
    func upsertSleepRows(_ rows: [SleepRow]) async throws {
        guard isActiveParticipant else { return }
        let uid = try await requireAuthedUserId()
        
        let fixedRows = rows.map { row in
            // ✅ Make sure every row uses the authed uid (RLS-safe)
            SleepRow(
                user_id: uid,
                hk_uuid: row.hk_uuid,
                start_time: row.start_time,
                end_time: row.end_time,
                state: row.state,
                source_bundle_id: row.source_bundle_id // <-- if you don't have this field, change to nil
            )
        }
        
        try await client
            .from("sleep_samples")
            .upsert(fixedRows, onConflict: "user_id,hk_uuid")
            .execute()
    }
    
    // MARK: Participants
    func upsertParticipant(sonaID: String) async throws {
        guard isActiveParticipant else { return }
        let uid = try await requireAuthedUserId()
        
        let participant = Participant(user_id: uid, sona_id: sonaID, is_active: true)
        
        _ = try await client
            .from("participants")
            .upsert(participant, onConflict: "user_id")
            .execute()
    }
    
    // MARK: Images
    func uploadImageDataAndRecord(_ data: Data, ext: String, mime: String) async throws {
        guard isActiveParticipant else { return }
        let uid = try await requireAuthedUserId()
        
        let filename = "\(UUID().uuidString).\(ext)"
        let path = "\(uid.uuidString.lowercased())/photos/\(filename)"
        let session = try await client.auth.session
        let prefix = String(path.split(separator: "/").first ?? "")
        
        print("SESSION UID:", session.user.id.uuidString)
        print("UPLOAD PATH:", path)
        print("PATH PREFIX:", prefix)
        
        try await client.storage
            .from("user-uploads")
            .upload(path, data: data, options: FileOptions(contentType: mime))
        
        var width: Int? = nil
        var height: Int? = nil
        if let img = UIImage(data: data) {
            width = Int(img.size.width * img.scale)
            height = Int(img.size.height * img.scale)
        }
        
        let row = MediaRow(
            user_id: uid,
            storage_path: path,
            mime_type: mime,
            bytes: data.count,
            width: width,
            height: height,
            duration_seconds: nil
        )
        
        try await client.from("media_uploads").insert(row).execute()
    }
    
    func uploadImageAndRecord(_ image: UIImage) async throws {
        guard isActiveParticipant else { return }
        let uid = try await requireAuthedUserId()
        
        guard let data = image.jpegData(compressionQuality: 0.90) else {
            throw NSError(domain: "upload", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "JPEG encoding failed"])
        }
        
        let path = "\(uid.uuidString.lowercased())/photos/\(UUID().uuidString).jpg"
        
        try await client.storage
            .from("user-uploads")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
        
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        
        let row = MediaRow(
            user_id: uid,
            storage_path: path,
            mime_type: "image/jpeg",
            bytes: data.count,
            width: width,
            height: height,
            duration_seconds: nil
        )
        
        try await client.from("media_uploads").insert(row).execute()
    }
    
    // MARK: Video
    func uploadVideoAndRecord(fileURL: URL) async throws {
        guard isActiveParticipant else { return }
        let uid = try await requireAuthedUserId()
        
        let sizeBytes = try fileSizeBytes(at: fileURL)
        guard sizeBytes > 0 else {
            throw NSError(domain: "VideoUpload", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "The selected video could not be read."])
        }
        guard sizeBytes <= maxVideoUploadBytes else {
            throw NSError(domain: "VideoUpload", code: 413,
                          userInfo: [NSLocalizedDescriptionKey:
                                        "This video is too large (\(humanMB(sizeBytes))). Please choose a shorter video (max \(humanMB(maxVideoUploadBytes)))."
                                    ])
        }
        
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let ext = fileURL.pathExtension.lowercased()
        let mime = UTType(filenameExtension: ext)?.preferredMIMEType ?? "video/quicktime"
        
        let filename = "\(UUID().uuidString).\(ext.isEmpty ? "mov" : ext)"
        let path = "\(uid.uuidString.lowercased())/videos/\(filename)"
        
        try await client.storage
            .from("user-uploads")
            .upload(path, data: data, options: FileOptions(contentType: mime))
        
        let asset = AVURLAsset(url: fileURL)
        let duration: Double = (try? await asset.load(.duration).seconds) ?? 0
        
        var width: Int? = nil
        var height: Int? = nil
        do {
            if let track = try await asset.loadTracks(withMediaType: .video).first {
                let naturalSize = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                let transformedSize = naturalSize.applying(transform)
                width  = Int(abs(transformedSize.width))
                height = Int(abs(transformedSize.height))
            }
        } catch {
            print("⚠️ Failed to load video dimensions: \(error)")
        }
        
        let row = MediaRow(
            user_id: uid,
            storage_path: path,
            mime_type: mime,
            bytes: data.count,
            width: width,
            height: height,
            duration_seconds: duration
        )
        
        try await client.from("media_uploads").insert(row).execute()
    }
    
    private let maxVideoUploadBytes: Int64 = 80 * 1024 * 1024
    
    private func fileSizeBytes(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }
    
    private func humanMB(_ bytes: Int64) -> String {
        String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
    
    // MARK: Streak
    func updateStreak(streakDays: [String]) async throws {
        guard isActiveParticipant else { return }
        let uid = try await requireAuthedUserId()
        
        let streakRow = StreakRow(
            user_id: uid,
            streak_days: streakDays,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("user_streaks")
            .upsert(streakRow, onConflict: "user_id")
            .execute()
    }
    
    // MARK: Opt-out
    func optOut(deleteData: Bool) async throws {
        await MainActor.run { setActive(false) }
        if deleteData { try await deleteAllUserData() }
        else { try await markUserInactive() }
    }
    
    func deleteAllUserData() async throws {
        let uid = try await requireAuthedUserId()
        
        let paths = try await fetchMediaStoragePaths(for: uid)
        if !paths.isEmpty { try await deleteStorageObjects(bucket: "user-uploads", paths: paths) }
        
        try await client.from("media_uploads").delete().eq("user_id", value: uid).execute()
        try await client.from("user_streaks").delete().eq("user_id", value: uid).execute()
        try await client.from("sleep_samples").delete().eq("user_id", value: uid).execute()
        try await client.from("participants").delete().eq("user_id", value: uid).execute()
    }
    
    private func fetchMediaStoragePaths(for userId: UUID) async throws -> [String] {
        let response = try await client
            .from("media_uploads")
            .select("storage_path")
            .eq("user_id", value: userId)
            .execute()
        
        return try JSONDecoder().decode([MediaPathRow].self, from: response.data).map { $0.storage_path }
    }
    
    private func deleteStorageObjects(bucket: String, paths: [String]) async throws {
        let chunkSize = 100
        var i = 0
        while i < paths.count {
            let chunk = Array(paths[i..<min(i + chunkSize, paths.count)])
            try await client.storage.from(bucket).remove(paths: chunk)
            i += chunkSize
        }
    }
    
    func markUserInactive() async throws {
        let uid = try await requireAuthedUserId()
        try await client.from("participants")
            .update(["is_active": false])
            .eq("user_id", value: uid)
            .execute()
    }
    
    // MARK: Opt-out Feedback
    struct OptOutFeedbackRow: Encodable {
        let reason: String
        let delete_requested: Bool
        let app_build: String?
    }

    func submitOptOutFeedback(reason: String, deleteRequested: Bool) async throws {
        // Ensure we have an anonymous session so role=authenticated
        _ = try await requireAuthedUserId()

        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        let row = OptOutFeedbackRow(
            reason: trimmed,
            delete_requested: deleteRequested,
            app_build: build
        )

        try await client
            .from("opt_out_feedback")
            .insert(row)
            .execute()
    }
    
    // MARK: DTOs
    
    // Row shape for `participants`
    struct Participant: Encodable {
        let user_id: UUID
        let sona_id: String
        let is_active: Bool
    }
    
    // Row shape for `media_uploads`
    struct MediaRow: Encodable {
        let user_id: UUID
        let storage_path: String
        let mime_type: String?
        let bytes: Int?
        let width: Int?
        let height: Int?
        let duration_seconds: Double?
    }
    
    // Row shape for `user_streaks`
    struct StreakRow: Encodable {
        let user_id: UUID
        let streak_days: [String]   // or change to JSONB if you prefer
        let updated_at: String      // ISO8601 string
    }
    
    // Row shape for selecting storage paths from `media_uploads`
    private struct MediaPathRow: Decodable {
        let storage_path: String
    }
}
