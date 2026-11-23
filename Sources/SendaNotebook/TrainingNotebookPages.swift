import SwiftUI
import SendaLogger
import SendaDomain

struct TrainingNotebookPages: View {
    let model: TrainingNotebookModel
    @Binding var layout: TrainingCalendarLayout
    @Environment(\.scenePhase) private var scenePhase
    @State private var today: TrainingDay

    init(model: TrainingNotebookModel, layout: Binding<TrainingCalendarLayout>) {
        self.model = model
        _layout = layout
        _today = State(initialValue: model.today)
    }

    var body: some View {
        Group {
            switch model.section {
            case .log:
                if let day = model.selectedDay {
                    TrainingDayView(model: model, day: day, layout: layout)
                } else if layout == .month {
                    TrainingMonthCalendar(model: model, today: today, selectedDay: calendarDay, showWeek: {
                        model.showWeek(containing: model.calendarDay) { layout = .week }
                    }, openWorkout: { model.openDay(model.calendarDay) })
                } else {
                    TrainingWeekView(model: model, today: today) {
                        if !model.weekDays.contains(model.calendarDay) {
                            model.selectCalendarDay(model.weekDays.contains(model.today) ? model.today : model.workspace.visibleWeek)
                        }
                        layout = .month
                    }
                }
            case .trends: TrainingTrendsView(model: model).id(model.landingResetID)
            case .learn: TrainingLibraryView(model: model).id(model.landingResetID)
            case .profile: TrainingProfileView(model: model).id(model.landingResetID)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { today = model.today }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = model.today
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            today = model.today
        }
    }

    private var calendarDay: Binding<TrainingDay> {
        Binding(get: { model.calendarDay }, set: { model.selectCalendarDay($0) })
    }
}
