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
                    .font(AppFont.largeTitle())
                    .foregroundStyle(Color.blue.opacity(0.88))
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
                .fill(AppSurfaceColor.lightPanel)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppSurfaceColor.lightPanelBorder, lineWidth: 1)
        }
    }
}

private struct OpportunityTypeButton: View {
    let type: OpportunityType
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Text(type.title)
                .font(AppFont.footnote(weight: .bold))
                .foregroundStyle(isSelected ? Color.white : Color.black.opacity(0.66))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    Capsule()
                        .fill(isSelected ? AppSurfaceColor.darkPill : AppSurfaceColor.mutedPill)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct OpportunityCard: View {
    let opportunity: Opportunity

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(opportunity.title)
                        .font(AppFont.headline())
                        .foregroundStyle(Color.black.opacity(0.86))

                    Spacer(minLength: 10)

                    Text(opportunity.category)
                        .font(AppFont.caption(weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.52))
                }

                Text(opportunity.description)
                    .font(AppFont.subheadline())
                    .foregroundStyle(Color.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)

                Text(opportunity.detail)
                    .font(AppFont.footnote(weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.46))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppSurfaceColor.lightPanelSecondary)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppSurfaceColor.lightPanelBorder, lineWidth: 1)
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
            detail: "Priority: deadlines and referrals"
        ),
        Opportunity(
            title: "Technical Interview Prep",
            type: .internships,
            category: "Practice",
            description: "Plan LeetCode sessions, mock interviews, resume reviews, and system design practice.",
            detail: "Focus: DS&A, behavioral, projects"
        ),
        Opportunity(
            title: "CS Events Calendar",
            type: .events,
            category: "Events",
            description: "Track hackathons, company info sessions, tech talks, workshops, and UGA computing events.",
            detail: "Add date, location, and RSVP link later"
        ),
        Opportunity(
            title: "Tech Talks & Workshops",
            type: .events,
            category: "Workshop",
            description: "Keep a running list of speaker events, skill workshops, and chapter-led learning sessions.",
            detail: "Good for RSVP links and reminders"
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

}

private struct Opportunity: Identifiable {
    let id = UUID()
    let title: String
    let type: OpportunityType
    let category: String
    let description: String
    let detail: String
}

#Preview("Opportunities") {
    OpportunitiesView()
        .padding(20)
        .background(AppTab.opportunities.theme.backgroundColor)
}
