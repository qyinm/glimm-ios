//
//  CaptureError.swift
//  glimm
//

import Foundation

enum CaptureError: LocalizedError {
    case sessionConfigFailed
    case cameraUnavailable
    case photoCaptureFailed

    var errorDescription: String? {
        switch self {
        case .sessionConfigFailed: return "Failed to configure camera session"
        case .cameraUnavailable: return "Camera is not available"
        case .photoCaptureFailed: return "Failed to capture photo"
        }
    }
}
