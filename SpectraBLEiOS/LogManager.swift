//
//  LogManager.swift
//  BLESDKCallDemo
//
//  Created by Spectra-iOS on 22/05/25.
//

import Foundation

public class LogManager {
    static let shared = LogManager()

    private let logFileName = "app_logs.txt"

    private var logFileURL: URL? {
        let fileManager = FileManager.default
        guard let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docsDir.appendingPathComponent(logFileName)
    }

    func writeLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)\n"

        guard let fileURL = logFileURL else { return }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Append to file
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            }
        } else {
            // Create file
            try? logEntry.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    

    func readLogs() -> URL? {
        return logFileURL
    }

    func clearLogs() {
        guard let fileURL = logFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
