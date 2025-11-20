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

final class SupabaseClient {
    static let shared = SupabaseClient()

    // ⬇️ Your project values (Project Settings → API)
    private let url = URL(string: "")!
    private let anonKey = ""

    private lazy var client = Supabase.SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey
    )

    // MARK: - Sleep

    /// Upsert rows into `sleep_samples` using a unique constraint on (user_id, hk_uuid)
    func upsertSleepRows(_ rows: [SleepRow]) async throws {
        try await client.database
            .from("sleep_samples")
            .upsert(rows, onConflict: "user_id,hk_uuid", returning: .minimal)
            .execute()
    }

    // MARK: - Media uploads

    /// Upload arbitrary image bytes (HEIC/JPEG/PNG/WEBP) + record a row
    func uploadImageDataAndRecord(_ data: Data,
                                  ext: String,
                                  mime: String,
                                  userId: UUID) async throws {
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
}

// MARK: - DTOs

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

