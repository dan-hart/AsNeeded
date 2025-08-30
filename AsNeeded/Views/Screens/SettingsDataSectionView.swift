import SwiftUI

struct SettingsDataSectionView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Data")
        .font(.title2)
        .fontWeight(.semibold)

      NavigationLink {
        DataManagementView()
              .padding()
          .navigationTitle("Data Management")
      } label: {
        HStack(spacing: 12) {
          Image(systemName: "externaldrive")
            .font(.system(size: 18, weight: .medium))
            .frame(width: 24, height: 24)
            .foregroundColor(.blue)

          VStack(alignment: .leading, spacing: 2) {
            Text("Data Management")
              .font(.body)
              .fontWeight(.medium)
            Text("Export, import, and clear your data")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .cornerRadius(12)
      }
      .buttonStyle(.plain)
    }
  }
}

#if DEBUG
#Preview {
  SettingsDataSectionView()
}
#endif
