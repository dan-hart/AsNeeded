import Foundation

/// Constants and required disclaimers for the SwiftRxNorm package
public struct RxNormConstants {
	
	/// Required NIH/NLM disclaimer that must be displayed in applications using this package
	/// 
	/// The NIH requires that any application using the RxNorm API display this disclaimer
	/// to users. You can access this constant to display it in your app's about section,
	/// terms of service, or wherever appropriate.
	///
	/// Example usage:
	/// ```swift
	/// Text(RxNormConstants.requiredDisclaimer)
	///     .font(.caption)
	///     .foregroundColor(.secondary)
	/// ```
	public static let requiredDisclaimer = """
		This product uses publicly available data from the U.S. National Library of Medicine (NLM), \
		National Institutes of Health, Department of Health and Human Services; \
		NLM is not responsible for the product and does not endorse or recommend this or any other product.
		"""
	
	/// Short version of the disclaimer for space-constrained UIs
	public static let shortDisclaimer = "Drug data provided by RxNorm from the U.S. National Library of Medicine."
	
	/// Medical advice disclaimer
	public static let medicalDisclaimer = """
		This information is for educational purposes only and should not be used as a substitute \
		for professional medical advice, diagnosis, or treatment. Always consult with a qualified \
		healthcare provider about medications.
		"""
	
	/// Full legal disclaimer combining NIH requirements and medical disclaimer
	public static let fullDisclaimer = """
		\(requiredDisclaimer)
		
		\(medicalDisclaimer)
		"""
	
	/// RxNorm API base URL
	static let apiBaseURL = "https://rxnav.nlm.nih.gov/REST/"
	
	/// RxNorm Terms of Service URL
	public static let termsOfServiceURL = "https://lhncbc.nlm.nih.gov/RxNav/TermsofService.html"
	
	/// RxNorm API Documentation URL  
	public static let apiDocumentationURL = "https://lhncbc.nlm.nih.gov/RxNav/APIs/RxNormAPIs.html"
}