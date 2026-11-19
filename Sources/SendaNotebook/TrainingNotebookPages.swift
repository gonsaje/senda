import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingPageMotion {
    static let detailOffset: CGFloat = 32
    let reduceMotion: Bool

    var animation: Animation { .easeInOut(duration: reduceMotion ? 0.14 : 0.24) }

    func opacityAnimation(appearing: Bool) -> Animation {
        reduceMotion ? animation : .easeOut(duration: appearing ? 0.16 : 0.10)
    }

    func transition(entryOffset: CGFloat) -> AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .offset(x: entryOffset).combined(with: .opacity.animation(opacityAnimation(appearing: true))),
            removal: .opacity.animation(opacityAnimation(appearing: false))
        )
    }
}

struct TrainingPage: Equatable {
    struct Identity: Hashable {
        let section: TrainingSection
        let isWorkout: Bool
    }

    let section: TrainingSection
    let day: TrainingDay?

    init(section: TrainingSection, selectedDay: TrainingDay?) {
        self.section = section
        day = section == .log ? selectedDay : nil
    }

    var identity: Identity { Identity(section: section, isWorkout: day != nil) }

    func entryOffset(from previous: Self, layout: LayoutDirection) -> CGFloat {
        guard identity != previous.identity else { return 0 }
        let offset: CGFloat
        if section == previous.section {
            offset = day == nil ? -TrainingPageMotion.detailOffset : TrainingPageMotion.detailOffset
        } else {
            let order = TrainingSection.allCases
            let currentIndex = order.firstIndex(of: section) ?? 0
            let previousIndex = order.firstIndex(of: previous.section) ?? 0
            offset = currentIndex > previousIndex ? 48 : -48
        }
        return layout == .rightToLeft ? -offset : offset
    }
}

struct TrainingNotebookPages: View {
    let model: TrainingNotebookModel
    @State private var page: TrainingPage
    @State private var entryOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layout

    init(model: TrainingNotebookModel) {
        self.model = model
        _page = State(initialValue: TrainingPage(section: model.section, selectedDay: model.selectedDay))
    }

    private var destination: TrainingPage {
        TrainingPage(section: model.section, selectedDay: model.selectedDay)
    }

    private var motion: TrainingPageMotion { TrainingPageMotion(reduceMotion: reduceMotion) }

    var body: some View {
        ZStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(page == destination)
                .accessibilityHidden(page != destination)
                .id(page.identity)
                .transition(motion.transition(entryOffset: entryOffset))
        }
        .clipped()
        .onChange(of: destination) { _, next in
            let offset = next.entryOffset(from: page, layout: layout)
            // Changes within a workout keep its view identity and editing state.
            guard offset != 0 else { page = next; return }
            // Navigation has already committed. Animate the displayed page alone.
            withAnimation(motion.animation) {
                entryOffset = offset
                page = next
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch page.section {
        case .log:
            if let day = page.day { TrainingDayView(model: model, day: day) }
            else { TrainingWeekView(model: model).id(model.landingResetID) }
        case .trends: TrainingTrendsView(model: model).id(model.landingResetID)
        case .learn: TrainingLibraryView(model: model).id(model.landingResetID)
        case .profile: TrainingProfileView(model: model).id(model.landingResetID)
        }
    }
}
