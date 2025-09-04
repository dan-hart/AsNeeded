//
//  AIStatusIndicator.swift
//  AsNeeded
//
//  Visual indicator showing when AI-powered features are active
//

import SwiftUI
import SFSafeSymbols

struct AIStatusIndicator: View {
	@State private var isAnimating = false
	let isActive: Bool
	let label: String
	
	init(isActive: Bool = false, label: String = "AI Enhanced") {
		self.isActive = isActive
		self.label = label
	}
	
	var body: some View {
		if #available(iOS 26.0, *), isActive {
			HStack(spacing: 4) {
				Image(systemSymbol: .sparkles)
					.font(.caption2)
					.foregroundStyle(.tint)
					.symbolEffect(.pulse, options: .repeating, value: isAnimating)
				
				Text(label)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(.thinMaterial, in: Capsule())
			.onAppear {
				isAnimating = true
			}
		}
	}
}

/// View modifier to easily add AI status indicator
struct AIEnhancedModifier: ViewModifier {
	let isActive: Bool
	let label: String
	
	func body(content: Content) -> some View {
		content
			.overlay(alignment: .topTrailing) {
				AIStatusIndicator(isActive: isActive, label: label)
					.padding(8)
			}
	}
}

extension View {
	/// Adds an AI status indicator overlay to the view
	func aiEnhanced(isActive: Bool = true, label: String = "AI Enhanced") -> some View {
		modifier(AIEnhancedModifier(isActive: isActive, label: label))
	}
}