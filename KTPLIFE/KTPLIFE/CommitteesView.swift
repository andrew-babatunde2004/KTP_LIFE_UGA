import SwiftUI

struct CommitteesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @State private var committees: [Committee] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var workingCommitteeIDs: Set<String> = []
    @State private var requestedCommitteeIDs: Set<String> = []

    private var service: ChapterResourcesService {
        ChapterResourcesService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    AppSectionHeading(
                        eyebrow: "Get Involved",
                        title: "Find your team",
                        systemImage: "person.3.fill"
                    )
                    .padding(.bottom, 6)

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
                                hasPendingRequest: committee.hasPendingMembershipRequest || requestedCommitteeIDs.contains(committee.id),
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
        .tint(AppSystemColor.primaryLabel)
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
                    requestedCommitteeIDs.remove(committee.id)
                } else {
                    try await service.requestCommitteeMembership(id: committee.id)
                    requestedCommitteeIDs.insert(committee.id)
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
    let hasPendingRequest: Bool
    let service: ChapterResourcesService
    let changeMembership: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                AppIconBadge(systemImage: "person.2.fill")

                VStack(alignment: .leading, spacing: 4) {
                    Text(committee.name)
                        .font(AppFont.headline())
                        .foregroundStyle(AppSystemColor.primaryLabel)

                    Text(committee.isMember ? "You’re part of this committee" : "Open to chapter members")
                        .font(AppFont.caption())
                        .foregroundStyle(AppSystemColor.secondaryLabel)
                }

                Spacer(minLength: 8)

                if let role = committee.role, committee.isMember {
                    Text(role.capitalized)
                        .font(AppFont.caption(weight: .bold))
                        .foregroundStyle(AppSystemColor.primaryLabel)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppSystemColor.insetBackground, in: Capsule())
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
                    .buttonStyle(.glass)
                }

                Spacer(minLength: 0)

                Button(membershipButtonTitle) {
                    changeMembership()
                }
                .font(AppFont.footnote(weight: .semibold))
                .modifier(CommitteeMembershipButtonStyle(isMember: committee.isMember))
                .disabled(isWorking || hasPendingRequest)
            }
        }
        .padding(18)
        .appElevatedSurface(radius: 24)
        .accessibilityElement(children: .contain)
    }

    private var membershipButtonTitle: String {
        if committee.isMember { return "Leave" }
        return hasPendingRequest ? "Request Pending" : "Request to Join"
    }
}

private struct CommitteeMembershipButtonStyle: ViewModifier {
    let isMember: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isMember ? AppSystemColor.primaryLabel : AppSystemColor.background)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                isMember ? AppSystemColor.insetBackground : AppSystemColor.primaryLabel,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(AppSystemColor.separator.opacity(isMember ? 0.7 : 0), lineWidth: 1)
            }
            .buttonStyle(.plain)
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
                            AppIconBadge(systemImage: "person.fill", size: 38)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(member.name)
                                    .font(AppFont.subheadline(weight: .semibold))
                                    .foregroundStyle(AppSystemColor.primaryLabel)

                                Text(member.role.capitalized)
                                    .font(AppFont.caption())
                                    .foregroundStyle(AppSystemColor.secondaryLabel)
                            }

                            Spacer(minLength: 8)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .appElevatedSurface(radius: 20)
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
        AppStatusSurface(message: message, systemImage: "person.3.sequence.fill")
    }
}
