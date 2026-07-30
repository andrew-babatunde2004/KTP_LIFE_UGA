//
//  HomeView.swift
//  KTPLIFE
//

import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthManager
    @State private var events: [CalendarEvent] = []
    @State private var isLoadingEvents = false
    @State private var eventsErrorMessage: String?
    @State private var homepageSlides: [HomepageSlide] = []
    @State private var isLoadingHomepageSlides = false

    let showDocuments: () -> Void
    let showCommittees: () -> Void

    private var calendarService: CalendarNetworkService {
        CalendarNetworkService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        PageScaffold(showsPageHeader: false) {
            VStack(alignment: .leading, spacing: 10) {
                heroSection

                if isLoadingHomepageSlides {
                    HomeSlideshowLoadingView()
                } else if !homepageSlides.isEmpty {
                    HomeSlideshow(slides: homepageSlides, apiService: apiService)
                }

                VStack(alignment: .leading, spacing: 30) {

                    thisWeekSection

                    actionSection
                }
            }
            .padding(.bottom, 12)
        }
        .task {
            await loadEvents()
        }
        .task {
            await loadCurrentProfile()
        }
        .task {
            await loadHomepageSlides()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(todayLabel.uppercased())
                .font(AppFont.caption(weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(HomeDesign.accent)

            Text(greeting)
                .font(AppFont.largeTitle(25))
                .foregroundStyle(HomeDesign.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .font(AppFont.title(22))
                    .foregroundStyle(HomeDesign.primaryText)

                Spacer()

                if !isLoadingEvents, eventsErrorMessage == nil {
                    Text(eventCountLabel)
                        .font(AppFont.caption(weight: .medium))
                        .foregroundStyle(HomeDesign.tertiaryText)
                }
            }
            .padding(.bottom, 8)

            if isLoadingEvents {
                HomeStatusRow(title: "Loading chapter events...")
            } else if let eventsErrorMessage {
                HomeStatusRow(title: eventsErrorMessage)
            } else if visibleWeekEvents.isEmpty {
                HomeStatusRow(title: "No chapter events this week.")
            } else {
                ForEach(Array(visibleWeekEvents.enumerated()), id: \.element.id) { index, event in
                    HomeEventRow(event: event)

                    if index < visibleWeekEvents.count - 1 {
                        Divider()
                            .padding(.leading, 70)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                actionButtons
            }
        } else {
            actionButtons
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            HomeActionButton(
                title: "Documents",
                systemImage: "doc.on.doc.fill",
                colorScheme: colorScheme,
                reduceTransparency: reduceTransparency,
                action: showDocuments
            )

            HomeActionButton(
                title: "Committees",
                systemImage: "person.3.fill",
                colorScheme: colorScheme,
                reduceTransparency: reduceTransparency,
                action: showCommittees
            )
        }
    }

    private var todayLabel: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var greeting: String {
        let salutation: String
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:
            salutation = "Good morning"
        case 12..<17:
            salutation = "Good afternoon"
        default:
            salutation = "Good evening"
        }

        guard let preferredUsername = authManager.currentUserPreferredUsername else {
            return "\(salutation)."
        }

        return "\(salutation), \(preferredUsername)."
    }

    private var eventCountLabel: String {
        weekEvents.count == 1 ? "1 event" : "\(weekEvents.count) events"
    }

    private var weekEvents: [CalendarEvent] {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }

        return events
            .filter { $0.endDate >= week.start && $0.startDate < week.end }
            .sorted { $0.startDate < $1.startDate }
    }

    private var visibleWeekEvents: [CalendarEvent] {
        Array(weekEvents.prefix(3))
    }

    @MainActor
    private func loadEvents() async {
#if DEBUG
        if isPreview {
            events = CalendarEvent.previewSamples
            eventsErrorMessage = nil
            return
        }
#endif

        isLoadingEvents = true
        eventsErrorMessage = nil

        do {
            events = try await calendarService.fetchCalendarEvents()
        } catch is CancellationError {
            return
        } catch {
            events = []
            eventsErrorMessage = "Could not load this week's events."
        }

        isLoadingEvents = false
    }

    @MainActor
    private func loadCurrentProfile() async {
        guard !isPreview else { return }

        do {
            let profile = try await apiService.fetchCurrentUserProfile()
            guard !Task.isCancelled else { return }
            authManager.updateCurrentUserProfile(profile)
        } catch {
            // The token claim remains the greeting fallback if the profile endpoint is unavailable.
        }
    }

    @MainActor
    private func loadHomepageSlides() async {
        guard !isPreview else { return }

        isLoadingHomepageSlides = true
        defer { isLoadingHomepageSlides = false }

        do {
            homepageSlides = try await apiService.fetchHomepageSlides()
        } catch is CancellationError {
            return
        } catch {
            // A missing highlight is non-blocking; the rest of Home remains usable.
            homepageSlides = []
        }
    }

}

private struct HomeSlideshow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var selectedSlide = 0
    let slides: [HomepageSlide]
    let apiService: KTPAPIService

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $selectedSlide) {
                ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                    HomepageSlideView(slide: slide, apiService: apiService)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 238)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 9, x: 0, y: 4)

            if slides.count > 1 {
                HomePageControl(
                    pageCount: slides.count,
                    selectedPage: selectedSlide,
                    reduceTransparency: reduceTransparency
                )
            }
        }
        .task {
            await rotateSlidesAutomatically()
        }
        .onChange(of: slides.map(\.id)) { _, _ in
            selectedSlide = min(selectedSlide, max(0, slides.count - 1))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chapter highlights slideshow")
    }

    /// Automatic slideshow rotation is intentionally centralized here. Adjust
    /// `HomeSlideshowConfiguration.rotationInterval` to change the cadence.
    private func rotateSlidesAutomatically() async {
        guard slides.count > 1 else { return }

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: HomeSlideshowConfiguration.rotationInterval)
            } catch {
                return
            }

            let nextSlide = (selectedSlide + 1) % slides.count
            if reduceMotion {
                selectedSlide = nextSlide
            } else {
                withAnimation(.smooth(duration: 0.45)) {
                    selectedSlide = nextSlide
                }
            }
        }
    }
}

private struct HomepageSlideView: View {
    @Environment(\.displayScale) private var displayScale
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var thumbnailRepository: GalleryThumbnailRepository
    let slide: HomepageSlide
    let apiService: KTPAPIService
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let linkURL = slide.linkURL {
                Button { openURL(linkURL) } label: { slideContent }
                    .buttonStyle(.plain)
            } else {
                slideContent
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .task(id: "\(slide.id)-\(Int((proxy.size.width * displayScale).rounded(.up)))") {
                        await loadImage(for: proxy.size)
                    }
            }
        }
    }

    private var slideContent: some View {
        ZStack(alignment: .bottomLeading) {
            AppSystemColor.elevatedBackground

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            if !slide.title.isEmpty || !slide.subtitle.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !slide.title.isEmpty {
                        Text(slide.title)
                            .font(AppFont.title(20))
                            .foregroundStyle(.white)
                    }

                    if !slide.subtitle.isEmpty {
                        Text(slide.subtitle)
                            .font(AppFont.subheadline())
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                    }
                }
                .padding(22)
            }
        }
    }

    private var accessibilityLabel: String {
        var label = slide.altText
        if let linkLabel = slide.linkLabel, !linkLabel.isEmpty {
            label += ". \(linkLabel)"
        } else if slide.linkURL != nil {
            label += ". Opens link"
        }
        return label
    }

    @MainActor
    private func loadImage(for size: CGSize) async {
        guard size.width > 0 else { return }
        image = await thumbnailRepository.image(
            for: "homepage-slide-\(slide.id)",
            pointSize: size.width,
            displayScale: displayScale,
            loadData: { try await apiService.fetchHomepageSlideMediaData(for: slide) }
        )
    }
}

private struct HomeSlideshowLoadingView: View {
    var body: some View {
        AppSystemColor.elevatedBackground
            .overlay { ProgressView("Loading chapter highlights...") }
            .frame(height: 238)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HomePageControl: View {
    let pageCount: Int
    let selectedPage: Int
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(
                        index == selectedPage
                            ? HomeDesign.accent
                            : HomeDesign.tertiaryText.opacity(0.5)
                    )
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .modifier(HomePageControlSurface(reduceTransparency: reduceTransparency))
        .accessibilityLabel("Slide \(selectedPage + 1) of \(pageCount)")
    }
}

private struct HomePageControlSurface: ViewModifier {
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(.clear, in: Capsule())
        } else {
            content.background(AppSystemColor.elevatedBackground, in: Capsule())
        }
    }
}

private struct HomeActionButton: View {
    let title: String
    let systemImage: String
    let colorScheme: ColorScheme
    let reduceTransparency: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(HomeDesign.accent)
                        .frame(width: 42, height: 42)
                        .background(
                            HomeDesign.accent.opacity(colorScheme == .dark ? 0.18 : 0.10),
                            in: Circle()
                        )

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(HomeDesign.tertiaryText)
                }

                Text(title)
                    .font(AppFont.headline())
                    .foregroundStyle(HomeDesign.primaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .modifier(HomeGlassActionSurface(
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        ))
    }
}

private struct HomeEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Text(event.startDate.formatted(.dateTime.weekday(.abbreviated).day()))
                .font(AppFont.footnote(weight: .semibold))
                .foregroundStyle(HomeDesign.accent)
                .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(AppFont.headline())
                    .foregroundStyle(HomeDesign.primaryText)

                Text(eventTimeLabel)
                    .font(AppFont.footnote())
                    .foregroundStyle(HomeDesign.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var eventTimeLabel: String {
        if Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
            let start = event.startDate.formatted(date: .omitted, time: .shortened)
            let end = event.endDate.formatted(date: .omitted, time: .shortened)
            return start == end ? start : "\(start)–\(end)"
        }

        return event.startDate.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct HomeStatusRow: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppFont.subheadline())
            .foregroundStyle(HomeDesign.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }
}

private struct HomeGlassActionSurface: ViewModifier {
    let colorScheme: ColorScheme
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .buttonStyle(.plain)
                .glassEffect(
                    .regular
                        .tint(HomeDesign.glassTint(for: colorScheme))
                        .interactive(),
                    in: .rect(cornerRadius: 22)
                )
        } else {
            content
                .buttonStyle(.plain)
                .background(
                    AppSystemColor.elevatedBackground,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppSystemColor.separator.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

private enum HomeDesign {
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let accent = AppSurfaceColor.primaryControl

    static func glassTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : accent.opacity(0.10)
    }
}

private enum HomeSlideshowConfiguration {
    /// Change this value to tune automatic slideshow rotation in one place.
    static let rotationInterval: Duration = .seconds(5)
}

#if DEBUG
#Preview("Home — Light") {
    HomeView(
        showDocuments: {},
        showCommittees: {}
    )
        .padding(.horizontal, 24)
        .background(AppTab.home.theme.previewBackground(.light))
        .environment(\.pageTheme, AppTab.home.theme)
        .environmentObject(AuthManager.previewSignedOut)
        .preferredColorScheme(.light)
}

#Preview("Home — Dark") {
    HomeView(
        showDocuments: {},
        showCommittees: {}
    )
        .padding(.horizontal, 24)
        .background(AppTab.home.theme.previewBackground(.dark))
        .environment(\.pageTheme, AppTab.home.theme)
        .environmentObject(AuthManager.previewSignedOut)
        .preferredColorScheme(.dark)
}
#endif
