//
//  Models.swift
//  Inoxity
//
//  Created by Rachael Kee on 12/15/25.
//

// Importing dependencies
import Foundation


// MARK: Shared Models

struct SleepSummary {
    let totalAsleepSec: TimeInterval
    let remSec: TimeInterval
    let coreSec: TimeInterval
    let deepSec: TimeInterval
    let awakeSec: TimeInterval
    let windowStart: Date
    let windowEnd: Date
}

struct SleepSegment {
    let startTime: Date
    let endTime: Date
    let stage: String // "Deep", "REM", "Core", "Awake"
}
