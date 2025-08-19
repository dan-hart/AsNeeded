import Foundation

/// Standardized units for medication doses.
public enum ANUnitConcept: String, Codable, CaseIterable, Equatable, Hashable {
    case milligram
    case gram
    case microgram
    case unit
    case tablet
    case capsule
    case chewable
    case lozenge
    case suppository
    case milliliter
    case liter
    case teaspoon
    case drop
    case sachet
    case puff
    case actuation
    case nebule
    case vial
    case patch
    case application
    case spray
    case strip
    case film
    case dose
    case ampule

    /// A user-facing string for display in UI.
    public var displayName: String {
        switch self {
        case .milligram: return "Milligrams"
        case .gram: return "Grams"
        case .microgram: return "Micrograms"
        case .unit: return "Units"
        case .tablet: return "Tablets"
        case .capsule: return "Capsules"
        case .chewable: return "Chewables"
        case .lozenge: return "Lozenges"
        case .suppository: return "Suppositories"
        case .milliliter: return "Milliliters"
        case .liter: return "Liters"
        case .teaspoon: return "Teaspoons"
        case .drop: return "Drops"
        case .sachet: return "Sachets"
        case .puff: return "Puffs"
        case .actuation: return "Actuations"
        case .nebule: return "Nebules"
        case .vial: return "Vials"
        case .patch: return "Patches"
        case .application: return "Applications"
        case .spray: return "Sprays"
        case .strip: return "Strips"
        case .film: return "Films"
        case .dose: return "Doses"
        case .ampule: return "Ampules"
        }
    }

    /// Abbreviation for medical or clinical use (e.g., "mg" for milligrams).
    public var abbreviation: String {
        switch self {
        case .milligram: return "mg"
        case .gram: return "g"
        case .microgram: return "mcg"
        case .unit: return "unit"
        case .tablet: return "tab"
        case .capsule: return "cap"
        case .chewable: return "chew"
        case .lozenge: return "loz"
        case .suppository: return "supp"
        case .milliliter: return "mL"
        case .liter: return "L"
        case .teaspoon: return "tsp"
        case .drop: return "gtt"
        case .sachet: return "sach"
        case .puff: return "puff"
        case .actuation: return "act"
        case .nebule: return "neb"
        case .vial: return "vial"
        case .patch: return "patch"
        case .application: return "app"
        case .spray: return "spr"
        case .strip: return "strip"
        case .film: return "film"
        case .dose: return "dose"
        case .ampule: return "amp"
        }
    }

    /// A brief clinical description for each unit.
    public var clinicalDescription: String {
        switch self {
        case .milligram: return "A metric unit of mass commonly used for medication dosing."
        case .gram: return "A metric unit of mass, used for larger medication doses."
        case .microgram: return "A small metric unit of mass for precise dosing."
        case .unit: return "A standardized quantity used for some biological medications."
        case .tablet: return "Solid oral medication, typically swallowed whole or split."
        case .capsule: return "Solid oral medication in a gelatin shell."
        case .chewable: return "A tablet designed to be chewed before swallowing."
        case .lozenge: return "A medicated tablet dissolving slowly in the mouth."
        case .suppository: return "Solid medication inserted into the rectum, vagina, or urethra."
        case .milliliter: return "A metric unit of volume for liquid medications."
        case .liter: return "A metric unit for larger liquid medication volumes."
        case .teaspoon: return "A small volume, approximately 5 mL, often used in pediatrics."
        case .drop: return "A single drop, used for eye, ear, or nasal medications."
        case .sachet: return "A small packet containing powder or granules."
        case .puff: return "A single actuation of an inhaler."
        case .actuation: return "Release of a dose from a device, such as an inhaler."
        case .nebule: return "A unit-dose container for nebulizer medications."
        case .vial: return "A small bottle for injectable or inhalation medications."
        case .patch: return "A medicated adhesive applied to the skin."
        case .application: return "A single use of a topical product (cream, ointment, gel, etc.)."
        case .spray: return "A single metered dose delivered as a spray."
        case .strip: return "A thin film placed in the mouth for absorption."
        case .film: return "A medicated film for buccal or sublingual absorption."
        case .dose: return "A general dosage unit when no specific type applies."
        case .ampule: return "A sealed glass container for a single dose of medication."
        }
    }

    /// All selectable units for use in UI (e.g., Picker).
    public static var selectableUnits: [ANUnitConcept] { allCases }
}
