//
//  Constants.swift
//  glimm
//

import Foundation
import CoreGraphics

enum AppConstants {
    /// Maximum character limit for notes
    static let noteMaxLength = 280

    /// Supported notification interval presets in hours
    static let notificationIntervalPresets = [2, 3, 4, 6]

    /// Minimum gap between notifications in minutes
    static let notificationMinimumGapMinutes = 30

    /// Number of days to schedule notifications ahead
    static let notificationScheduleDays = 7

    /// Maximum duration for a single audio note in seconds
    static let maxAudioNoteDuration: TimeInterval = 60

    /// JPEG compression quality for exported images
    static let imageCompressionQuality: CGFloat = 0.8

    /// App version from Bundle
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// App build number from Bundle
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

enum AppURLs {
    static let privacy = URL(string: "https://glimm-landing-page.vercel.app/privacy")!
    static let terms = URL(string: "https://glimm-landing-page.vercel.app/terms")!
}

enum DesignSystem {
    enum CornerRadius {
        static let card: CGFloat = 24
        static let button: CGFloat = 16
        static let input: CGFloat = 12
        static let small: CGFloat = 8
    }

    enum Spacing {
        static let tabBarBottom: CGFloat = 100
    }
}
