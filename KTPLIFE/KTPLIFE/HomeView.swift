//
//  HomeView.swift
//  KTPLIFE
//

import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var authManager: AuthManager
    @State private var events: [CalendarEvent] = []
    @State private var isLoadingEvents = false
    @State private var eventsErrorMessage: String?
    @State private var homepageSlides: [HomepageSlide] = []
    @State private var isLoadingHomepageSlides = false
    @State private var heroScrollOffset: CGFloat = 0

    let showDocuments: () -> Void
    let showCommittees: () -> Void
    let showPolls: () -> Void
    let showAnnouncements: () -> Void
    let showMeetings: () -> Void
    let openQRScanner: () -> Void

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
        GeometryReader { viewport in
            let expandedHeroHeight = viewport.size.height * HomeHeroConfiguration.expandedHeightRatio
            let currentHeroHeight = heroHeight(from: expandedHeroHeight)
            let showsHero = isLoadingHomepageSlides || !homepageSlides.isEmpty

            ZStack(alignment: .top) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if showsHero {
                            // This spacer reserves exactly the height of the pinned hero,
                            // letting the content move up as the hero compacts.
                            Color.clear
                                .frame(height: currentHeroHeight)
                        }

                        VStack(alignment: .leading, spacing: 24) {
                            heroSection
                            homeNavigation
                            thisWeekSection
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }
                .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
                    max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                }) { _, newOffset in
                    heroScrollOffset = newOffset
                }

                if isLoadingHomepageSlides {
                    HomeHeroSlideshowLoadingView(height: currentHeroHeight)
                } else if !homepageSlides.isEmpty {
                    HomeHeroSlideshow(
                        slides: homepageSlides,
                        apiService: apiService,
                        width: viewport.size.width,
                        height: currentHeroHeight,
                        topSafeAreaInset: viewport.safeAreaInsets.top,
                        reduceTransparency: reduceTransparency,
                        openQRScanner: openQRScanner
                    )
                }
            }
            .ignoresSafeArea(edges: .top)
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

    private var heroCollapseProgress: CGFloat {
        min(max(heroScrollOffset / HomeHeroConfiguration.collapseDistance, 0), 1)
    }

    private func heroHeight(from expandedHeight: CGFloat) -> CGFloat {
        expandedHeight - (
            (expandedHeight - (expandedHeight * HomeHeroConfiguration.collapsedHeightRatio))
                * heroCollapseProgress
        )
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
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(
                title: "This week",
                trailingText: !isLoadingEvents && eventsErrorMessage == nil ? eventCountLabel : nil
            )

            VStack(spacing: 0) {
                if isLoadingEvents {
                    HomeStatusRow(
                        title: "Loading chapter events...",
                        systemImage: "calendar.badge.clock"
                    )
                } else if let eventsErrorMessage {
                    HomeStatusRow(
                        title: eventsErrorMessage,
                        systemImage: "exclamationmark.circle"
                    )
                } else if visibleWeekEvents.isEmpty {
                    HomeStatusRow(
                        title: "No chapter events this week.",
                        systemImage: "calendar"
                    )
                } else {
                    ForEach(Array(visibleWeekEvents.enumerated()), id: \.element.id) { index, event in
                        HomeEventRow(event: event)

                        if index < visibleWeekEvents.count - 1 {
                            Divider()
                                .padding(.leading, 88)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .modifier(HomeAgendaSurface())
        }
    }

    private var homeNavigation: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)],
            spacing: 0
        ) {
            HomeNavigationItem(
                title: "Documents",
                systemImage: "doc.on.doc.fill",
                action: showDocuments
            )

            HomeNavigationItem(
                title: "Committees",
                systemImage: "person.3.fill",
                action: showCommittees
            )

            HomeNavigationItem(
                title: "Polls",
                systemImage: "chart.bar.fill",
                action: showPolls
            )

            HomeNavigationItem(
                title: "Announcements",
                systemImage: "megaphone.fill",
                action: showAnnouncements
            )

            HomeNavigationItem(
                title: "Meetings",
                systemImage: "person.2.badge.gearshape",
                action: showMeetings
            )
            .gridCellColumns(2)
        }
        .padding(.vertical, 4)
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
        weekEvents.count == 1 ? "1 EVENT" : "\(weekEvents.count) EVENTS"
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

private struct HomeSectionHeader: View {
    let title: String
    var eyebrow: String?
    var subtitle: String?
    var trailingText: String?

    var body: some View {
        HStack(alignment: subtitle == nil ? .firstTextBaseline : .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(AppFont.caption(weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(HomeDesign.accent)
                }

                Text(title)
                    .font(AppFont.title(21))
                    .foregroundStyle(HomeDesign.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.footnote())
                        .foregroundStyle(HomeDesign.secondaryText)
                }
            }

            Spacer(minLength: 12)

            if let trailingText {
                Text(trailingText)
                    .font(AppFont.caption(weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(HomeDesign.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(HomeDesign.accent.opacity(0.10), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeHeroSlideshow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSlide = 0
    let slides: [HomepageSlide]
    let apiService: KTPAPIService
    let width: CGFloat
    let height: CGFloat
    let topSafeAreaInset: CGFloat
    let reduceTransparency: Bool
    let openQRScanner: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedSlide) {
                ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                    HomepageSlideView(slide: slide, apiService: apiService, pageWidth: width)
                        .frame(width: width, height: height)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(width: width, height: height)

            HomePageControl(
                pageCount: slides.count,
                selectedPage: selectedSlide,
                reduceTransparency: reduceTransparency
            )
            .padding(.bottom, 13)

            VStack {
                HStack {
                    HomeQRScannerButton(action: openQRScanner, reduceTransparency: reduceTransparency)
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, topSafeAreaInset + 10)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(width: width, height: height)
        .clipped()
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
    let pageWidth: CGFloat
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
                ZStack {
                    // Keep the original artwork intact. The soft background fills any
                    // extra space for portrait or landscape slides without cropping
                    // text that is part of the image itself.
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 18)
                        .scaleEffect(1.08)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
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
                            .font(AppFont.title(24))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !slide.subtitle.isEmpty {
                        Text(slide.subtitle)
                            .font(AppFont.subheadline())
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(2)
                    }
                }
                .frame(
                    width: max(0, pageWidth - (HomeHeroConfiguration.titleHorizontalInset * 2)),
                    alignment: .leading
                )
                .padding(.leading, HomeHeroConfiguration.titleHorizontalInset)
                .padding(.top, 22)
                .padding(.bottom, 28)
                .frame(width: pageWidth, alignment: .leading)
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

private struct HomeHeroSlideshowLoadingView: View {
    let height: CGFloat

    var body: some View {
        AppSystemColor.elevatedBackground
            .overlay { ProgressView("Loading chapter highlights...") }
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
}

private struct HomeQRScannerButton: View {
    let action: () -> Void
    let reduceTransparency: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(HomeQRControlSurface(reduceTransparency: reduceTransparency))
        .accessibilityLabel("Scan a QR code")
    }
}

private struct HomeQRControlSurface: ViewModifier {
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.tint(.black.opacity(0.16)).interactive(), in: .circle)
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.30), lineWidth: 1)
                }
        }
    }
}

private struct HomePageControl: View {
    let pageCount: Int
    let selectedPage: Int
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(
                        index == selectedPage
                            ? .white
                            : .white.opacity(reduceTransparency ? 0.65 : 0.45)
                    )
                    .frame(width: index == selectedPage ? 18 : 6, height: 6)
            }
        }
        .animation(.smooth(duration: 0.25), value: selectedPage)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Slide \(selectedPage + 1) of \(pageCount)")
    }
}

private struct HomeNavigationItem: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(HomeDesign.accent)

                Text(title)
                    .font(AppFont.footnote(weight: .semibold))
                    .foregroundStyle(HomeDesign.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(title)")
    }
}

private struct HomeEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 2) {
                Text(event.startDate.formatted(.dateTime.weekday(.abbreviated)))
                    .font(AppFont.caption(weight: .semibold))
                    .textCase(.uppercase)

                Text(event.startDate.formatted(.dateTime.day()))
                    .font(AppFont.title(20))
            }
            .foregroundStyle(HomeDesign.accent)
            .frame(width: 56, height: 58)
            .background(
                HomeDesign.accent.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(event.title)
                    .font(AppFont.headline())
                    .foregroundStyle(HomeDesign.primaryText)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .semibold))

                    Text(eventTimeLabel)
                        .font(AppFont.footnote())
                }
                .foregroundStyle(HomeDesign.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
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
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(HomeDesign.accent)
                .frame(width: 38, height: 38)
                .background(HomeDesign.accent.opacity(0.10), in: Circle())

            Text(title)
                .font(AppFont.subheadline())
                .foregroundStyle(HomeDesign.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeAgendaSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                AppSystemColor.elevatedBackground,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppSystemColor.separator.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 5)
    }
}

private enum HomeDesign {
    static let primaryText = AppSystemColor.primaryLabel
    static let secondaryText = AppSystemColor.secondaryLabel
    static let tertiaryText = AppSystemColor.secondaryLabel.opacity(0.68)
    static let accent = AppSystemColor.primaryLabel
}

private enum HomeSlideshowConfiguration {
    /// Change this value to tune automatic slideshow rotation in one place.
    static let rotationInterval: Duration = .seconds(5)
}

private enum HomeHeroConfiguration {
    static let collapseDistance: CGFloat = 170
    /// Fraction of the screen occupied by the full-size slideshow.
    static let expandedHeightRatio: CGFloat = 0.68
    static let collapsedHeightRatio: CGFloat = 0.72
    static let titleHorizontalInset: CGFloat = 30
}

#if DEBUG
#Preview("Home — Light") {
    HomeView(
        showDocuments: {},
        showCommittees: {},
        showPolls: {},
        showAnnouncements: {},
        showMeetings: {},
        openQRScanner: {}
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
        showCommittees: {},
        showPolls: {},
        showAnnouncements: {},
        showMeetings: {},
        openQRScanner: {}
    )
        .padding(.horizontal, 24)
        .background(AppTab.home.theme.previewBackground(.dark))
        .environment(\.pageTheme, AppTab.home.theme)
        .environmentObject(AuthManager.previewSignedOut)
        .preferredColorScheme(.dark)
}
#endif
