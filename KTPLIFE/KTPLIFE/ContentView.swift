//
//  ContentView.swift
//  KTPLIFE
//
//  Created by Seyi Babatunde on 6/16/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @State private var email = ""
    @State private var password = ""
    @State private var isAuthenticated = false
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack {
            backgroundView

            Group {
                if isAuthenticated {
                    appShellView
                } else {
                    loginView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .safeAreaPadding(.bottom, isAuthenticated ? 116 : 32)
        }
        .safeAreaInset(edge: .bottom) {
            if isAuthenticated {
                tabBarView
            }
        }
    }

    // MARK: - Extracted background
    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.20, blue: 0.40),
                    Color(red: 0.17, green: 0.30, blue: 0.54),
                    Color(red: 0.07, green: 0.14, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 300, height: 300)
                .blur(radius: 75)
                .offset(x: 135, y: -250)

            Circle()
                .fill(Color.cyan.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 60)
                .offset(x: -150, y: 280)
        }
    }

    // MARK: - Extracted tab bar
    private var tabBarView: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            selectedTab = tab
                        }
                    } label: {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 54, height: 48)
                            .contentShape(Capsule())
                            .accessibilityLabel(tab.title)
                            .foregroundStyle(.white.opacity(selectedTab == tab ? 1 : 0.74))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        selectedTab == tab
                            ? .clear.tint(Color.white.opacity(0.16))
                            : .clear.tint(Color.white.opacity(0.06)),
                        in: Capsule()
                    )
                }
            }
            .padding(10)
            .glassEffect(.clear.tint(Color.white.opacity(0.08)), in: Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItem(_ item: Item) {
        withAnimation {
            modelContext.delete(item)
        }
    }

    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    private func signIn() {
        guard canSignIn else { return }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            isAuthenticated = true
        }
    }

    private func returnToAuthForTesting() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            isAuthenticated = false
            selectedTab = .home
            password = ""
        }
    }

    // Main app shell
    private var appShellView: some View {
        Group {
            switch selectedTab {
            case .home:
                homeView
            case .messages:
                messagesView
            case .calendar:
                calendarView
            }
        }
    }

    // Auth page
    private var loginView: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 18) {
                Image("KTPLogo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(maxWidth: 220, maxHeight: 78)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .shadow(color: .white.opacity(0.08), radius: 14, y: 6)
            }

            VStack(alignment: .leading, spacing: 14) {
                authField(
                    title: "Email",
                    prompt: "name@uga.edu",
                    text: $email,
                    icon: "envelope.fill"
                )

                authSecureField(
                    title: "Password",
                    prompt: "Enter password",
                    text: $password,
                    icon: "lock.fill"
                )
            }

            Button(action: signIn) {
                Text("Sign In")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(canSignIn ? 1 : 0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.plain)
            .glassEffect(
                .clear.tint(Color.white.opacity(canSignIn ? 0.16 : 0.06)),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .disabled(!canSignIn)

            Text("This screen is the local auth gate right now. Hook the sign-in action to your real auth flow when you add it.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            Spacer()
        }
    }

    // Home page
    private var homeView: some View {
        pageScaffold(
            subtitle: "Stay on top of chapter activity.",
            sectionTitle: "Home",
            sectionSubtitle: "Recent updates",
            header: {
                Image("KTPLogo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(maxWidth: 180, maxHeight: 64, alignment: .leading)
                    .shadow(color: .white.opacity(0.08), radius: 12, y: 4)
            },
            trailing: {
                Button(action: addItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.white.opacity(0.12))
            }
        ) {
            Button(action: returnToAuthForTesting) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .glassEffect(.clear.tint(Color.white.opacity(0.12)), in: Circle())

                    Text("Back to Auth")
                        .font(.system(.headline, design: .rounded, weight: .bold))

                    Spacer()

                    Text("Testing")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .foregroundStyle(.white)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .glassCard()

            if items.isEmpty {
                emptyState(
                    title: "No activity yet",
                    message: "Tap the plus button to add your first item."
                )
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(items) { item in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.timestamp, format: .dateTime.month(.abbreviated).day().year())
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(item.timestamp, format: .dateTime.hour().minute())
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            Spacer()

                            Button {
                                deleteItem(item)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .frame(width: 38, height: 38)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.clear.tint(Color.white.opacity(0.12)), in: Circle())
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                    }
                }
            }
        }
    }

    // Calendar page
    private var calendarView: some View {
        Text("Calendar view coming soon!")
    }

    // Messages page
    private var messagesView: some View {
        pageScaffold(
            title: "Messages",
            subtitle: "Quick chapter communication in one place.",
            sectionTitle: "Inbox",
            sectionSubtitle: "Recent threads"
        ) {
            LazyVStack(spacing: 14) {
                ForEach(Array(Self.messagePreviews.enumerated()), id: \.offset) { index, thread in
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(thread.title)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)

                            Text(thread.preview)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            Text(thread.time)
                                .font(.system(.footnote, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))

                            Image(systemName: index == 0 ? "message.badge.fill" : "message.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .frame(width: 38, height: 38)
                                .glassEffect(.clear.tint(Color.white.opacity(0.12)), in: Circle())
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }
            }
        }
    }

    private func pageScaffold<Header: View, Trailing: View, Content: View>(
        title: String? = nil,
        subtitle: String,
        sectionTitle: String,
        sectionSubtitle: String,
        @ViewBuilder header: () -> Header = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let title {
                            Text(title)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        } else {
                            header()
                        }

                        Text(subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Spacer()

                    trailing()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(sectionTitle)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text(sectionSubtitle)
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.66))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .glassCard(radius: 30)

                content()
            }
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .glassCard(radius: 28)
    }

    private func authField(title: String, prompt: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 18)

                TextField("", text: text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.42)))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .glassCard(radius: 24)
        }
    }

    private func authSecureField(title: String, prompt: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 18)

                SecureField("", text: text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.42)))
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .glassCard(radius: 24)
        }
    }
}

private extension ContentView {
    static let messagePreviews = [
        MessageThread(title: "General Thread", preview: "Chapter updates are live for this week.", time: "Now"),
        MessageThread(title: "Recruitment", preview: "Reminder: recruitment meeting starts at 7:00 PM.", time: "4:15"),
        MessageThread(title: "Committee Notes", preview: "Your committee notes were shared with the team.", time: "Yesterday")
    ]
}

private struct MessageThread {
    let title: String
    let preview: String
    let time: String
}

private extension View {
    func glassCard(radius: CGFloat = 26) -> some View {
        glassEffect(
            .clear.tint(Color.white.opacity(0.07)),
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
    }
}

private enum AppTab:  CaseIterable, Identifiable {
    case home
    case messages
    case calendar

    var id: Self { self }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .messages:
            return "message.fill"
        case .calendar:
            return "calendar"
        }
    }
    
    var title: String {
        switch self {
        case .home:
            return "Home"
        case .messages:
            return "Messages"
        case .calendar:
            return "Calendar"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewModelContainer.shared)
}

@MainActor
private enum PreviewModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Item.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }()
}
