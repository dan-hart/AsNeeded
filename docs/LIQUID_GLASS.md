# Liquid Glass Design Guide

> Complete reference for implementing Apple's iOS 26 Liquid Glass design language in the AsNeeded app

## Table of Contents
- [Overview](#overview)
- [Core Principles](#core-principles)
- [Technical Implementation](#technical-implementation)
- [Design Patterns](#design-patterns)
- [Current App Analysis](#current-app-analysis)
- [Recommendations](#recommendations)
- [Migration Guide](#migration-guide)
- [Accessibility](#accessibility)
- [Best Practices](#best-practices)
- [Anti-Patterns](#anti-patterns)

---

## Overview

### What is Liquid Glass?

Liquid Glass is Apple's most significant iOS design update since the flat design revolution of iOS 7 (2013). Introduced at WWDC 2025 with iOS 26, it represents a fundamental shift toward **dynamic, translucent, spatially-aware interfaces**.

**Key Characteristics:**
- **Translucent material** that reflects and refracts surrounding content
- **Real-time rendering** with dynamic specular highlights
- **Movement-responsive** animations and depth effects
- **Content-first philosophy** where UI adapts to user focus
- **Spatial depth** through layered transparency

**Platform Availability:**
- iOS 26+
- iPadOS 26+
- macOS Tahoe 26+
- watchOS 26+
- tvOS 26+

---

## Core Principles

### 1. Layer-Based Hierarchy

Liquid Glass introduces a 3D spatial environment where UI exists in distinct layers:

```
┌─────────────────────────────┐
│   Dynamic Layer (20-40%)    │  ← Interaction overlays, tooltips
├─────────────────────────────┤
│   Solid Layer (100%)        │  ← Critical text, icons
├─────────────────────────────┤
│   Glass Layer (40-70%)      │  ← Floating controls, buttons
├─────────────────────────────┤
│   Background Layer (100%)   │  ← Foundational content
└─────────────────────────────┘
```

**Transparency Notation:**
- **100% Opacity**: Vital content that must always be readable
- **70% Opacity**: Supporting elements (secondary buttons, labels)
- **40% Opacity**: Decorative guidance (borders, separators)
- **20% Opacity**: Subtle atmospheric effects (glows, shadows)

### 2. Content-First Philosophy

**"Interfaces that respond to users rather than demanding adaptation"**

- **Scrolling**: Tab bars/toolbars collapse to maximize content, expand when interaction is needed
- **Focus**: UI elements recede during reading/viewing, emerge during interaction
- **Depth**: Controls float above content as a distinct functional layer

### 3. Dynamic Interaction

Liquid Glass isn't just visual—it's **interactive**:
- Responds to touch with ripple effects
- Reacts to device motion with parallax
- Adapts to background content dynamically
- Uses real-time GPU rendering for smooth effects

### 4. Harmony

Design balances three elements:
1. **Hardware**: Device shapes inform UI element curves
2. **Content**: Information hierarchy drives transparency levels
3. **Controls**: Rounded forms follow natural touch patterns

---

## Technical Implementation

### SwiftUI `.glassEffect()` Modifier

The primary way to implement Liquid Glass in SwiftUI is the `.glassEffect()` modifier.

#### Basic Usage

```swift
Text("Hello, Liquid Glass!")
	.padding()
	.background {
		RoundedRectangle(cornerRadius: 16)
			.glassEffect(.regular)
	}
```

#### Material Variants

```swift
// Regular glass (default) - standard translucency
.glassEffect(.regular)

// Clear glass - maximum transparency
.glassEffect(.clear)
```

#### Tinted Glass

```swift
// Blue tint
.glassEffect(.regular.tint(.blue))

// Subtle tint with reduced opacity
.glassEffect(.regular.tint(.orange.opacity(0.3)))

// Medication-specific tint
.glassEffect(.regular.tint(medication.displayColor.opacity(0.2)))
```

#### Interactive Glass

```swift
// Responds to touch/hover with dynamic effects
.glassEffect(.regular.interactive(true))

// Use for all interactive controls:
Button("Log Dose") {
	performAction()
}
.background {
	Capsule()
		.glassEffect(.regular.interactive(true))
}
```

#### Custom Shapes

```swift
// Capsule (preferred for controls)
.glassEffect(.regular, in: .capsule)

// Ellipse
.glassEffect(.regular, in: .ellipse)

// Button border (system-provided shape)
.glassEffect(.regular, in: .buttonBorder)

// Custom rounded rectangle
.glassEffect(.regular, in: .rect(cornerRadius: 20))
```

#### Conditional Enablement

```swift
@State private var isGlassed = false

Text("Toggleable Glass")
	.padding()
	.glassEffect(.regular, in: .buttonBorder, isEnabled: isGlassed)
```

### Migration from Pre-iOS 26

#### Before (iOS 18-25)
```swift
VStack {
	Text("Content")
}
.background(.regularMaterial)
.clipShape(RoundedRectangle(cornerRadius: 16))
```

#### After (iOS 26+)
```swift
VStack {
	Text("Content")
}
.background {
	RoundedRectangle(cornerRadius: 16)
		.glassEffect(.regular)
}
```

#### Backward Compatibility

```swift
@available(iOS 26, *)
extension View {
	func adaptiveGlass() -> some View {
		if #available(iOS 26, *) {
			return self.background {
				RoundedRectangle(cornerRadius: 16)
					.glassEffect(.regular)
			}
		} else {
			return self
				.background(.regularMaterial)
				.clipShape(RoundedRectangle(cornerRadius: 16))
		}
	}
}
```

---

## Design Patterns

### Pattern 1: Floating Action Buttons

**Use Case**: Primary actions that need to stand out

```swift
Button(action: performAction) {
	Label("Log Dose", systemImage: "plus.circle.fill")
		.font(.headline)
		.foregroundStyle(.white)
}
.padding()
.background {
	Capsule()
		.fill(Color.accentColor.gradient)
		.glassEffect(.regular.interactive(true))
}
.shadow(color: .accentColor.opacity(0.4), radius: 12, y: 6)
```

**Why:**
- Capsule shape follows iOS 26 standards
- Gradient + glass creates premium feel
- Interactive glass responds to touch
- Shadow provides depth

### Pattern 2: Glass Cards

**Use Case**: Content containers, sections

```swift
VStack(alignment: .leading, spacing: 16) {
	Text("Section Title")
		.font(.headline)

	Text("Content here")
		.foregroundStyle(.secondary)
}
.padding(20)
.background {
	RoundedRectangle(cornerRadius: 20, style: .continuous)
		.glassEffect(.regular)
}
.overlay {
	RoundedRectangle(cornerRadius: 20, style: .continuous)
		.strokeBorder(
			LinearGradient(
				colors: [.white.opacity(0.3), .clear],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			),
			lineWidth: 0.5
		)
}
```

**Why:**
- `.continuous` corner radius is smoother
- Glass effect with gradient border is signature Liquid Glass look
- Maintains consistency across app

### Pattern 3: Interactive Pills/Chips

**Use Case**: Tags, filters, quick actions

```swift
ForEach(options, id: \.self) { option in
	Button(option.label) {
		selectedOption = option
	}
	.font(.subheadline.weight(.medium))
	.padding(.horizontal, 16)
	.padding(.vertical, 10)
	.background {
		Capsule()
			.glassEffect(
				selectedOption == option
					? .regular.tint(.accent.opacity(0.3))
					: .regular,
				isEnabled: true
			)
			.interactive(true)
	}
	.foregroundStyle(selectedOption == option ? .accent : .primary)
}
```

**Why:**
- Selected state uses tinted glass
- Interactive modifier for touch response
- Capsule is iOS 26 standard for pills

### Pattern 4: Modal Sheets

**Use Case**: Overlays, forms, detail views

```swift
NavigationStack {
	ScrollView {
		// Content
	}
	.background {
		Color.clear
			.glassEffect(.clear) // Subtle overlay
	}
}
.presentationBackground {
	Color.clear
		.background(.regularMaterial) // System handles glass
}
```

**Why:**
- Use system-provided `.regularMaterial` for sheet backgrounds
- Let iOS 26 handle sheet glass effects automatically
- Content uses clear glass for layering

### Pattern 5: Hero Sections

**Use Case**: Large prominent headers

```swift
VStack(spacing: 20) {
	// Animated glass icon
	ZStack {
		// Blur halo
		Circle()
			.fill(.accent.opacity(0.2).gradient)
			.frame(width: 120, height: 120)
			.blur(radius: 20)

		// Glass circle
		Circle()
			.frame(width: 100, height: 100)
			.glassEffect(.regular)

		// Icon
		Image(systemName: "pills.fill")
			.font(.largeTitle)
			.foregroundStyle(.accent.gradient)
	}

	Text("Add Medication")
		.font(.largeTitle.bold())
}
```

**Why:**
- Layered glass creates depth
- Blur halo adds atmosphere
- Glass circle provides structure

---

## Current App Analysis

### ✅ Strengths

1. **Solid Foundation**
	- Uses `.regularMaterial` extensively (19 files, 297 occurrences)
	- Custom `GlassCardModifier` component
	- Consistent corner radii and spacing

2. **Good Hierarchy**
	- Layered transparency (icons, cards, backgrounds)
	- Appropriate use of shadows for depth
	- Gradient borders on glass surfaces

3. **Component Architecture**
	- Reusable glass components
	- Well-documented patterns
	- Preview support

### ⚠️ Gaps vs iOS 26 Standards

| Current | iOS 26 Standard | Priority |
|---------|----------------|----------|
| `.regularMaterial` | `.glassEffect(.regular)` | **High** |
| Static glass | Interactive glass | **High** |
| `RoundedRectangle` controls | `Capsule` controls | **High** |
| Manual gradients | Automatic specular highlights | Medium |
| Some glass-on-glass stacking | Avoid stacking | Medium |
| No tinted glass | Tinted for primary actions | Medium |

### 📊 Coverage Analysis

**Files Using Glass Materials:**
- `GlassCardModifier.swift` - Main glass component ⭐
- `HeroSectionComponent.swift` - Hero sections with glass icons ⭐
- `MedicationRowComponent.swift` - Card-style rows (96+ lines of glass styling) ⭐
- `LogDoseView.swift` - Modal with multiple glass sections ⭐
- `QuickLogToastView.swift` - Toast notifications
- 14+ more component files

**Total Glass Surface Area**: ~40% of visible UI uses glass/material effects

---

## Recommendations

### 🔥 High Priority

#### 1. Update `GlassCardModifier`

**Impact**: Single point of change affects entire app

**Current:**
```swift
.background(
	RoundedRectangle(cornerRadius: cornerRadius)
		.fill(.regularMaterial)
		.shadow(...)
		.overlay(/* gradient border */)
)
```

**Recommended:**
```swift
.background {
	RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		.glassEffect(.regular)
		.shadow(...)
		.overlay(/* keep gradient border */)
}
```

**Files Affected**: All 19+ files using `.glassCard()` modifier

#### 2. Make Interactive Buttons Responsive

**Files**: `MedicationRowComponent.swift`, `LogDoseView.swift`

**Current:**
```swift
Button("Log Dose") { ... }
	.background(
		RoundedRectangle(...)
			.fill(medication.displayColor.gradient)
	)
```

**Recommended:**
```swift
Button("Log Dose") { ... }
	.background {
		RoundedRectangle(...)
			.fill(medication.displayColor.gradient)
			.glassEffect(.regular.interactive(true))
	}
```

**Why**: Buttons will respond to touch with dynamic glass effects

#### 3. Transition to Capsule Shapes

**Files**: `LogDoseView.swift` (unit selector, quick actions)

**Current:**
```swift
Button(unit.displayName) { ... }
	.background(
		Capsule()
			.fill(selectedUnit == unit ? .accent : .secondary.opacity(0.1))
	)
```

**Recommended:**
```swift
Button(unit.displayName) { ... }
	.background {
		Capsule()
			.glassEffect(
				selectedUnit == unit
					? .regular.tint(.accent.opacity(0.3))
					: .regular,
				in: .capsule,
				isEnabled: true
			)
			.interactive(true)
	}
```

**Why**: Matches iOS 26 control standards, adds tinted glass for selected state

#### 4. Add Tinted Glass to CTAs

**Files**: Primary action buttons throughout app

**Pattern:**
```swift
.background {
	Capsule()
		.fill(actionColor.gradient)
		.glassEffect(.regular.tint(actionColor.opacity(0.2)))
		.interactive(true)
}
```

**Where**:
- "Add Medication" button → `.tint(.accent.opacity(0.2))`
- "Log Dose" buttons → `.tint(medication.displayColor.opacity(0.2))`
- Save/confirm buttons → `.tint(.accent.opacity(0.2))`

### 🔶 Medium Priority

#### 5. Reduce Glass-on-Glass Stacking

**Issue**: Some views stack multiple `.regularMaterial` layers

**Files to Check**:
- `LogDoseView.swift` - Sections inside scrollview with material background
- Modal sheets with glass cards inside

**Fix**: Use solid backgrounds for nested content
```swift
// Parent
ScrollView {
	VStack { ... }
}
.background(.regularMaterial) // Glass background

// Children - use solid, not glass
.background(Color(.systemBackground)) // ✅ Solid
.background(.regularMaterial)          // ❌ Glass-on-glass
```

#### 6. Dynamic Navigation Bar

**File**: `MedicationListView.swift`

**Pattern**: Tab bar should collapse on scroll down, expand on scroll up

```swift
.toolbar(.hidden, for: .tabBar) // On scroll down
.toolbar(.visible, for: .tabBar) // On scroll up
```

Requires scroll position tracking.

### 🔷 Low Priority (Polish)

#### 7. Specular Highlight Overlays

Add subtle animated gradients to large glass surfaces:

```swift
.overlay {
	LinearGradient(
		colors: [
			.white.opacity(0.3),
			.clear,
			.white.opacity(0.1)
		],
		startPoint: .topLeading,
		endPoint: .bottomTrailing
	)
	.blendMode(.overlay)
}
```

#### 8. Motion-Responsive Effects

Add subtle parallax to hero sections:

```swift
.offset(y: scrollOffset * 0.5)
.opacity(1 - (scrollOffset / 200))
```

---

## Migration Guide

### Phase 1: Foundation (1-2 hours)

1. **Update `GlassCardModifier`**
	- Replace `.regularMaterial` with `.glassEffect(.regular)`
	- Test throughout app
	- Verify dark mode appearance

2. **Create `AdaptiveGlassModifier`**
	- Backward compatibility wrapper
	- Handles iOS 26 detection
	- Provides `.adaptiveGlass()` modifier

### Phase 2: Interactive Elements (2-3 hours)

3. **Update Primary Buttons**
	- Add `.interactive(true)` to all CTAs
	- Test touch response
	- Verify haptic feedback still works

4. **Add Tinted Glass**
	- Primary actions get tinted glass
	- Use medication colors for context
	- Test contrast/readability

### Phase 3: Shape Refinement (1-2 hours)

5. **Transition Controls to Capsules**
	- Unit selectors → Capsule
	- Quick action buttons → Capsule
	- Tags/chips → Capsule
	- Keep rounded rectangles for cards/containers

6. **Verify Hierarchy**
	- Check for glass-on-glass stacking
	- Fix nested materials
	- Test component composition

### Phase 4: Polish (1-2 hours)

7. **Add Specular Highlights**
	- Large hero sections
	- Modal sheets
	- Empty state views

8. **Test Accessibility**
	- Reduced Transparency mode
	- Increased Contrast mode
	- VoiceOver navigation

**Total Estimated Time: 6-9 hours**

---

## Accessibility

### Automatic Adaptations

Liquid Glass **automatically respects** system accessibility settings:

#### Reduced Transparency
```swift
// System handles this automatically
.glassEffect(.regular) // Becomes solid background when Reduced Transparency is on
```

#### Increased Contrast
```swift
// Glass effects automatically adjust contrast
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

if reduceTransparency {
	.background(.systemBackground) // Solid
} else {
	.glassEffect(.regular) // Glass
}
```

#### Reduced Motion
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

.symbolEffect(
	.bounce,
	options: reduceMotion ? .speed(0) : .default
)
```

### Best Practices

**1. Always Provide Solid Fallbacks**
```swift
.background {
	if #available(iOS 26, *) {
		RoundedRectangle(cornerRadius: 16)
			.glassEffect(.regular)
	} else {
		RoundedRectangle(cornerRadius: 16)
			.fill(.regularMaterial)
	}
}
```

**2. Ensure Text Contrast**
- Minimum 4.5:1 for normal text
- Minimum 3:1 for large text (18pt+)
- Use `.contrastingForegroundColor()` for custom backgrounds

**3. Avoid Relying on Glass Effects Alone**
- Use icons + text labels
- Provide haptic feedback
- Include accessibility labels

**4. Test with Settings**
- Display & Brightness → Display → Reduce Transparency (ON)
- Accessibility → Display & Text Size → Increase Contrast (ON)
- Accessibility → Motion → Reduce Motion (ON)

---

## Best Practices

### ✅ DO

**1. Use Capsules for Controls**
```swift
Button("Action") { ... }
	.background {
		Capsule()
			.glassEffect(.regular.interactive(true))
	}
```

**2. Layer Glass Logically**
```
Background (solid) → Glass Layer (controls) → Content (solid text)
```

**3. Tint Primary Actions**
```swift
.glassEffect(.regular.tint(.accent.opacity(0.3)))
```

**4. Add Interactive to Buttons**
```swift
.glassEffect(.regular.interactive(true))
```

**5. Use Gradient Borders**
```swift
.overlay {
	RoundedRectangle(cornerRadius: 16)
		.strokeBorder(
			LinearGradient(
				colors: [.white.opacity(0.3), .clear],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			),
			lineWidth: 0.5
		)
}
```

**6. Continuous Corner Style**
```swift
RoundedRectangle(cornerRadius: 16, style: .continuous)
```

**7. Test in Both Themes**
- Light mode: Glass should feel airy
- Dark mode: Glass should feel deep

### ❌ DON'T

**1. Stack Glass on Glass**
```swift
// ❌ BAD
VStack {
	Text("Content")
		.background(.regularMaterial) // Glass #1
}
.background(.regularMaterial) // Glass #2 - stacking!

// ✅ GOOD
VStack {
	Text("Content")
		.background(.systemBackground) // Solid
}
.background(.regularMaterial) // Glass
```

**2. Use Static Glass for Interactive Elements**
```swift
// ❌ BAD
Button("Tap Me") { ... }
	.glassEffect(.regular) // No interaction response

// ✅ GOOD
Button("Tap Me") { ... }
	.glassEffect(.regular.interactive(true))
```

**3. Over-Tint**
```swift
// ❌ BAD
.glassEffect(.regular.tint(.accent)) // Too opaque, loses glass effect

// ✅ GOOD
.glassEffect(.regular.tint(.accent.opacity(0.2))) // Subtle tint
```

**4. Use Glass for Everything**
```swift
// Critical text should be on solid backgrounds
Text("Important Info")
	.padding()
	.background(.systemBackground) // ✅ Solid background
```

**5. Mix Shape Styles**
```swift
// ❌ INCONSISTENT
Button("A") { ... }.background(Capsule()...)
Button("B") { ... }.background(RoundedRectangle(...)...) // Different shape

// ✅ CONSISTENT
Button("A") { ... }.background(Capsule()...)
Button("B") { ... }.background(Capsule()...)
```

**6. Ignore Accessibility**
```swift
// Always test with Reduced Transparency
```

---

## Anti-Patterns

### ⚠️ Pattern: "Glass Soup"

**Problem**: Everything is glass, nothing has hierarchy

```swift
// ❌ ANTI-PATTERN
VStack {
	headerCard // glass
	contentSection // glass
	actionButtons // glass
}
.background(.regularMaterial) // glass background too
```

**Solution**: Use solid elements to create contrast

```swift
// ✅ BETTER
VStack {
	headerCard // glass
	contentSection // SOLID background
	actionButtons // glass
}
.background(.systemGroupedBackground) // solid background
```

### ⚠️ Pattern: "Invisible Controls"

**Problem**: Glass buttons on glass backgrounds with low contrast

```swift
// ❌ ANTI-PATTERN
Button("Action") { ... }
	.glassEffect(.regular) // Glass button
	.foregroundStyle(.secondary) // Low contrast text
```

**Solution**: Ensure adequate contrast, use solid text colors

```swift
// ✅ BETTER
Button("Action") { ... }
	.glassEffect(.regular.tint(.accent.opacity(0.3)))
	.foregroundStyle(.accent) // High contrast
	.fontWeight(.semibold) // Better readability
```

### ⚠️ Pattern: "Static Interactive Elements"

**Problem**: Buttons don't respond to interaction

```swift
// ❌ ANTI-PATTERN
Button("Log Dose") { ... }
	.glassEffect(.regular) // No .interactive(true)
```

**Solution**: All buttons should be interactive

```swift
// ✅ BETTER
Button("Log Dose") { ... }
	.glassEffect(.regular.interactive(true))
```

### ⚠️ Pattern: "Rounded Rectangle Everything"

**Problem**: Using rounded rectangles where capsules are more appropriate

```swift
// ❌ ANTI-PATTERN
HStack {
	ForEach(options) { option in
		Button(option) { ... }
			.background(RoundedRectangle(cornerRadius: 12)...)
	}
}
```

**Solution**: Use capsules for pill-style controls

```swift
// ✅ BETTER
HStack {
	ForEach(options) { option in
		Button(option) { ... }
			.background(Capsule()...)
	}
}
```

---

## Quick Reference

### Common Modifiers

```swift
// Basic glass
.glassEffect(.regular)

// Tinted glass
.glassEffect(.regular.tint(.blue.opacity(0.3)))

// Interactive glass (buttons)
.glassEffect(.regular.interactive(true))

// Custom shape
.glassEffect(.regular, in: .capsule)

// Conditional
.glassEffect(.regular, isEnabled: showGlass)
```

### Shape Recommendations

| Element Type | Recommended Shape | Example |
|-------------|-------------------|---------|
| Buttons | `Capsule()` | Unit selectors, quick actions |
| Cards | `RoundedRectangle(cornerRadius: 16-20, style: .continuous)` | Content sections |
| Containers | `RoundedRectangle(cornerRadius: 16-20, style: .continuous)` | Form sections |
| Pills/Chips | `Capsule()` | Tags, filters |
| Icons | `Circle()` or `RoundedRectangle` | Medication icons |
| Modals | System-provided | `.presentationBackground` |

### Material Variants

| Material | Use Case | Transparency |
|----------|----------|--------------|
| `.regular` | Most surfaces | Medium (70%) |
| `.clear` | Overlays needing max transparency | High (20%) |
| `.tint(.color)` | Primary actions, emphasis | Medium + tint |
| `.interactive(true)` | All interactive controls | Dynamic |

---

## Resources

### Official Apple Documentation
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) *(Requires Apple Developer account)*
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- WWDC 2025 Session 219: "Meet Liquid Glass"
- WWDC 2025 Session 323: "Build a SwiftUI app with the new design"

### Community Resources
- [SwiftUI Snippets: Liquid Glass Introduction](https://swiftuisnippets.wordpress.com/2025/06/14/introducing-liquid-glass-the-new-look-feel-of-apple-platforms/)
- [Create with Swift: Exploring Liquid Glass](https://www.createwithswift.com/exploring-a-new-visual-language-liquid-glass/)
- [MockFlow: Designing iOS 26 Screens](https://mockflow.com/blog/designing-ios-26-screens-with-liquid-glass-design)

### Design Tools
- iOS 26 UI Kit (Figma/Sketch) - Available on Apple Design Resources
- SF Symbols 6 - Includes glass-optimized symbols
- Xcode 26 Previews - Real-time glass effect preview

---

## Changelog

### Version 1.0 (2025-01-13)
- Initial documentation
- Complete iOS 26 Liquid Glass reference
- Current app analysis
- Migration recommendations
- Code examples and patterns
- Best practices and anti-patterns

---

**Questions or suggestions?** Update this document as the app evolves and iOS 26 patterns mature.
