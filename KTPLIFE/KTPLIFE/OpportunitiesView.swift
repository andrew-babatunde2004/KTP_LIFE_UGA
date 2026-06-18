//
//  OpportunitiesView.swift
//  KTPLIFE
//

import SwiftUI

struct OpportunitiesView: View {
    @State private var selectedType: OpportunityType = .internships

    var body: some View {
        PageScaffold(
            header: {
                OpportunitiesHeader(selectedType: $selectedType)
            }
        ) {
            LazyVStack(spacing: 14) {
                ForEach(filteredOpportunities) { opportunity in
                    OpportunityCard(opportunity: opportunity)
                }
            }
        }
    }

    private var filteredOpportunities: [Opportunity] {
        Self.opportunities.filter { $0.type == selectedType }
    }
}

private struct OpportunitiesHeader: View {
    @Binding var selectedType: OpportunityType

    var body: some View {
        // VStack (alignment: leading <- to the left, center <- to the center, trailing <- to the right) 
        VStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Opportunities")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .multilineTextAlignment(.center)
            }
            // HStack (alignment: top, center, bottom)
            HStack(spacing: 10) {
                ForEach(OpportunityType.allCases) { type in
                    OpportunityTypeButton(
                        type: type,
                        isSelected: selectedType == type,
                        select: { selectedType = type }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.58))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct OpportunityTypeButton: View {
    let type: OpportunityType
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 13, weight: .bold))

                Text(type.title)
                    .font(.system(.footnote, design: .rounded, weight: .bold))
            }
            .foregroundStyle(isSelected ? Color.white : Color.black.opacity(0.66))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(isSelected ? Color.black.opacity(0.82) : Color.black.opacity(0.06))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct OpportunityCard: View {
    let opportunity: Opportunity

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: opportunity.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.78))
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.06), in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(opportunity.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.86))

                    Spacer(minLength: 10)

                    Text(opportunity.category)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.52))
                }

                Text(opportunity.description)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)

                Text(opportunity.detail)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.46))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
    }
}

private extension OpportunitiesView {
    static let opportunities = [
        Opportunity(
            title: "Summer Internship Tracker",
            type: .internships,
            category: "Internship",
            description: "Keep links, deadlines, and application status for software, data, security, and product roles.",
            detail: "Priority: deadlines and referrals",
            icon: "briefcase.fill"
        ),
        Opportunity(
            title: "Technical Interview Prep",
            type: .internships,
            category: "Practice",
            description: "Plan LeetCode sessions, mock interviews, resume reviews, and system design practice.",
            detail: "Focus: DS&A, behavioral, projects",
            icon: "terminal.fill"
        ),
        Opportunity(
            title: "CS Events Calendar",
            type: .events,
            category: "Events",
            description: "Track hackathons, company info sessions, tech talks, workshops, and UGA computing events.",
            detail: "Add date, location, and RSVP link later",
            icon: "calendar.badge.clock"
        ),
        Opportunity(
            title: "Tech Talks & Workshops",
            type: .events,
            category: "Workshop",
            description: "Keep a running list of speaker events, skill workshops, and chapter-led learning sessions.",
            detail: "Good for RSVP links and reminders",
            icon: "person.3.sequence.fill"
        )
    ]
}

private enum OpportunityType: String, CaseIterable, Identifiable {
    case internships
    case events

    var id: Self { self }

    var title: String {
        switch self {
        case .internships:
            return "Internships"
        case .events:
            return "Events"
        }
    }

    var icon: String {
        switch self {
        case .internships:
            return "briefcase.fill"
        case .events:
            return "calendar"
        }
    }
}

private struct Opportunity: Identifiable {
    let id = UUID()
    let title: String
    let type: OpportunityType
    let category: String
    let description: String
    let detail: String
    let icon: String
}

#Preview("Opportunities") {
    OpportunitiesView()
        .padding(20)
        .background(AppTab.opportunities.theme.backgroundColor)
}
