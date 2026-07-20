import SwiftUI

struct CommitteesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @State private var committees: [Committee] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var workingCommitteeIDs: Set<String> = []

    private var service: ChapterResourcesService {
        ChapterResourcesService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    if isLoading {
                        CommitteeStatusView(message: "Loading committees...")
                    } else if let loadError {
                        CommitteeStatusView(message: loadError)
                    } else if committees.isEmpty {
                        CommitteeStatusView(message: "No committees are available yet.")
                    } else {
                        ForEach(committees) { committee in
                            CommitteeCard(
                                committee: committee,
                                isWorking: workingCommitteeIDs.contains(committee.id),
                                service: service,
                                changeMembership: { changeMembership(for: committee) }
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(AppSystemColor.background)
            .navigationTitle("Committees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppFont.subheadline(weight: .semibold))
                }
            }
            .task {
                await loadCommittees()
            }
            .refreshable {
                await loadCommittees()
            }
        }
        .background(AppSystemColor.background.ignoresSafeArea())
    }

    @MainActor
    private func loadCommittees() async {
        isLoading = true
        loadError = nil
        do {
            committees = try await service.fetchCommittees().sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } catch is CancellationError {
            return
        } catch {
            committees = []
            loadError = chapterResourceErrorMessage(for: error)
        }
        isLoading = false
    }

    @MainActor
    private func changeMembership(for committee: Committee) {
        guard !workingCommitteeIDs.contains(committee.id) else { return }
        workingCommitteeIDs.insert(committee.id)

        Task {
            defer { workingCommitteeIDs.remove(committee.id) }
            do {
                if committee.isMember {
                    try await service.leaveCommittee(id: committee.id)
                } else {
                    try await service.joinCommittee(id: committee.id)
                }
                await loadCommittees()
            } catch {
                loadError = chapterResourceErrorMessage(for: error)
            }
        }
    }
}

private struct CommitteeCard: View {
    let committee: Committee
    let isWorking: Bool
    let service: ChapterResourcesService
    let changeMembership: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(committee.name)
                    .font(AppFont.headline())
                    .foregroundStyle(AppSystemColor.primaryLabel)

                Spacer(minLength: 8)

                if let role = committee.role, committee.isMember {
                    Text(role.capitalized)
                        .font(AppFont.caption(weight: .semibold))
                        .foregroundStyle(AppSystemColor.secondaryLabel)
                }
            }

            HStack(spacing: 12) {
                if committee.isMember {
                    NavigationLink {
                        CommitteeMembersView(committee: committee, service: service)
                    } label: {
                        Text("View Members")
                            .font(AppFont.footnote(weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                }

                Spacer(minLength: 0)

                Button(committee.isMember ? "Leave" : "Join") {
                    changeMembership()
                }
                .font(AppFont.footnote(weight: .semibold))
                .modifier(CommitteeMembershipButtonStyle(isMember: committee.isMember))
                .disabled(isWorking)
            }
        }
        .padding(18)
        .background(
            AppSystemColor.elevatedBackground,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppSystemColor.separator.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct CommitteeMembershipButtonStyle: ViewModifier {
    let isMember: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isMember {
            content.buttonStyle(.bordered)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

private struct CommitteeMembersView: View {
    let committee: Committee
    let service: ChapterResourcesService

    @State private var members: [CommitteeMember] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if isLoading {
                    CommitteeStatusView(message: "Loading members...")
                } else if let loadError {
                    CommitteeStatusView(message: loadError)
                } else if members.isEmpty {
                    CommitteeStatusView(message: "No members have joined yet.")
                } else {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            Text(member.name)
                                .font(AppFont.subheadline(weight: .semibold))
                                .foregroundStyle(AppSystemColor.primaryLabel)

                            Spacer(minLength: 8)

                            Text(member.role.capitalized)
                                .font(AppFont.caption())
                                .foregroundStyle(AppSystemColor.secondaryLabel)
                        }
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            AppSystemColor.elevatedBackground,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(AppSystemColor.background)
        .navigationTitle(committee.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMembers()
        }
        .refreshable {
            await loadMembers()
        }
    }

    @MainActor
    private func loadMembers() async {
        isLoading = true
        loadError = nil
        do {
            members = try await service.fetchCommitteeMembers(id: committee.id).sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } catch is CancellationError {
            return
        } catch {
            members = []
            loadError = chapterResourceErrorMessage(for: error)
        }
        isLoading = false
    }
}

private struct CommitteeStatusView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppFont.subheadline())
            .foregroundStyle(AppSystemColor.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                AppSystemColor.elevatedBackground,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
    }
}
