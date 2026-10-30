// ReminderListView.swift
// SwiftUI view for displaying and managing existing medication reminders

import ANModelKit
import DHLoggingKit
import SFSafeSymbols
import SwiftUI

struct ReminderListView: View {
	@ObservedObject private var demoMode = DemoModeState.shared
    let medication: ANMedicationConcept
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontFamily) private var fontFamily
    @StateObject private var notificationManager = NotificationManager.shared
    private let logger = DHLogger(category: "ReminderListView")

    @State private var reminders: [ReminderDetail] = []
    @State private var isLoading = true
    @State private var showingDeleteConfirm = false
    @State private var reminderToDelete: ReminderDetail?

    @ScaledMetric private var emptyStateSpacing: CGFloat = 16
    @ScaledMetric private var rowSpacing: CGFloat = 8
    @ScaledMetric private var smallSpacing: CGFloat = 4

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading reminders...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if reminders.isEmpty {
                    emptyStateView
                } else {
                    remindersList
                }
            }
            .customNavigationTitle("Scheduled Reminders")
            .toolbar {
				ToolbarItem(placement: reminders.isEmpty ? .topBarTrailing : .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }

                if !reminders.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Delete All", role: .destructive) {
                            showingDeleteConfirm = true
                            reminderToDelete = nil
                        }
                        .font(.customFont(fontFamily, style: .body))
                    }
                }
            }
            .tint(.accent)
            .task {
                await loadReminders()
            }
            .refreshable {
                await loadReminders()
            }
            .alert(reminderToDelete == nil ? String(localized: "Delete All Reminders?") : String(localized: "Delete Reminder?"), isPresented: $showingDeleteConfirm) {
                if let reminder = reminderToDelete {
                    Button("Delete", role: .destructive) {
                        Task {
                            await deleteReminder(reminder)
                        }
                    }
                } else {
                    Button("Delete All", role: .destructive) {
                        Task {
                            await clearAllReminders()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if reminderToDelete != nil {
                    Text("This reminder will be removed. Your medication and dose history will stay unchanged.")
                } else {
                    Text("All reminders for this medication will be removed. Your medication and dose history will stay unchanged.")
                }
            }
            .font(.customFont(fontFamily, style: .body))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: emptyStateSpacing) {
            Image(systemSymbol: .bellSlash)
                .font(.largeTitle.weight(.medium))
                .foregroundColor(.secondary)

            Text("No Scheduled Reminders")
                .font(.customFont(fontFamily, style: .title2))
                .fontWeight(.semibold)

            Text("You haven't set any reminders for \(medication.demoDisplayName) yet.")
                .demoNameRedacted()
                .font(.customFont(fontFamily, style: .body))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

	private var remindersList: some View {
		List {
			Section {
				ForEach(reminders) { reminder in
					ReminderRow(
						reminder: reminder,
						onDelete: {
							reminderToDelete = reminder
							showingDeleteConfirm = true
						}
					)
				}
			} footer: {
				Text("Scheduled reminders use dates and times you choose. Optional next-dose alerts are managed separately.")
					.font(.customFont(fontFamily, style: .caption))
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

    private func loadReminders() async {
        logger.debug("Loading medication reminders")
        isLoading = true

        let reminderDetails = await notificationManager.getReminderDetails(for: medication)
        await MainActor.run {
            self.reminders = reminderDetails
            self.isLoading = false
        }
        logger.info("Loaded \(reminderDetails.count) reminders")
    }

    private func deleteReminder(_ reminder: ReminderDetail) async {
        logger.info("Deleting reminder")

        await notificationManager.cancelSpecificReminder(withIdentifier: reminder.id)
        await loadReminders()

        logger.info("Reminder deleted successfully")
    }

    private func clearAllReminders() async {
        logger.info("Clearing all medication reminders")

        await notificationManager.cancelReminder(for: medication)
        await loadReminders()

        logger.info("All reminders cleared successfully")
    }
}

struct ReminderRow: View {
	@ObservedObject private var demoMode = DemoModeState.shared
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let reminder: ReminderDetail
    let onDelete: () -> Void

    @ScaledMetric private var rowSpacing: CGFloat = 8
    @ScaledMetric private var smallSpacing: CGFloat = 4
    @ScaledMetric private var rowVerticalPadding: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: smallSpacing) {
                    Text(demoMode.text(reminder.title))
                        .demoNameRedacted()
                        .font(.customFont(fontFamily, style: .headline))
                        .noTruncate()

                    if !reminder.body.isEmpty {
                        Text(demoMode.text(reminder.body))
                            .demoNameRedacted()
                            .font(.customFont(fontFamily, style: .subheadline))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemSymbol: .trash)
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
				.accessibilityLabel("Delete reminder: \(reminder.title), \(nextFireText)")
				.accessibilityHint("Asks for confirmation before deleting")
            }

            timingLayout {
                Label {
                    Text(nextFireText)
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemSymbol: .clock)
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundColor(.secondary)
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }

                if reminder.isRepeating {
                    Label {
                        Text(reminder.repeatInfo ?? String(localized: "Recurring"))
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemSymbol: .repeat)
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, rowVerticalPadding)
    }

    private var nextFireText: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDate(reminder.nextFireDate, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return String(localized: "Today at \(formatter.string(from: reminder.nextFireDate))")
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(reminder.nextFireDate, inSameDayAs: tomorrow)
        {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return String(localized: "Tomorrow at \(formatter.string(from: reminder.nextFireDate))")
        } else if calendar.isDate(reminder.nextFireDate, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.setLocalizedDateFormatFromTemplate("EEEEjm")
            return formatter.string(from: reminder.nextFireDate)
        } else {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.setLocalizedDateFormatFromTemplate("MMMdjm")
            return formatter.string(from: reminder.nextFireDate)
        }
    }

	private var timingLayout: AnyLayout {
		if dynamicTypeSize.isAccessibilitySize {
			AnyLayout(VStackLayout(alignment: .leading, spacing: rowSpacing))
		} else {
			AnyLayout(HStackLayout())
		}
	}
}

#Preview {
    ReminderListView(
        medication: ANMedicationConcept(
            clinicalName: "Albuterol",
            nickname: "Inhaler"
        )
    )
}
