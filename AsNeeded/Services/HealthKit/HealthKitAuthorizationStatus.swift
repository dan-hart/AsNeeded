// HealthKitAuthorizationStatus.swift
// Wrapper around HealthKit authorization status with user-friendly messaging.

import Foundation

/// Authorization status for HealthKit access
enum HealthKitAuthorizationStatus: Equatable {
	/// User has not been asked for authorization yet
	case notDetermined

	/// HealthKit is not available on this device (e.g., iPad without Health app)
	case notAvailable

	/// User has denied authorization
	case denied

	/// User has granted authorization
	case authorized

	/// Authorization status is unknown or could not be determined
	case unknown

	/// User-facing display text
	var displayText: String {
		switch self {
		case .notDetermined:
			return "Not Connected"
		case .notAvailable:
			return "Not Available"
		case .denied:
			return "Access Denied"
		case .authorized:
			return "Connected"
		case .unknown:
			return "Unknown"
		}
	}

	/// Detailed explanation of the status
	var detailText: String {
		switch self {
		case .notDetermined:
			return "AsNeeded hasn't requested access to Apple Health yet. Connect to start syncing your medication data."
		case .notAvailable:
			return "Apple Health is not available on this device. HealthKit features require an iPhone, Apple Watch, or other compatible device."
		case .denied:
			return "AsNeeded doesn't have access to Apple Health. To enable sync, go to Settings > Health > Data Access & Devices > AsNeeded and turn on permissions."
		case .authorized:
			return "AsNeeded is connected to Apple Health and can sync your medication data."
		case .unknown:
			return "The authorization status could not be determined. Please try again."
		}
	}

	/// Whether the user can take action to change this status
	var canRequestAuthorization: Bool {
		switch self {
		case .notDetermined, .denied:
			return true
		case .notAvailable, .authorized, .unknown:
			return false
		}
	}

	/// Whether HealthKit features are available with this status
	var isAvailableForSync: Bool {
		return self == .authorized
	}

	/// Action button text for this status
	var actionButtonText: String? {
		switch self {
		case .notDetermined:
			return "Connect to Apple Health"
		case .denied:
			return "Open Health Settings"
		case .notAvailable, .authorized, .unknown:
			return nil
		}
	}
}
