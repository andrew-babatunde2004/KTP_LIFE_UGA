//
//  PageScaffold.swift
//  KTPLIFE
//

import SwiftUI

struct PageScaffold<Content: View>: View {
    let title: String?
    let subtitle: String?
    let sectionTitle: String?
    let sectionSubtitle: String?
    let showsPageHeader: Bool
    let header: AnyView
    let trailing: AnyView
    @ViewBuilder let content: () -> Content

    init<Header: View, Trailing: View>(
        title: String? = nil,
        subtitle: String? = nil,
        sectionTitle: String? = nil,
        sectionSubtitle: String? = nil,
        showsPageHeader: Bool = true,
        @ViewBuilder header: @escaping () -> Header = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.sectionTitle = sectionTitle
        self.sectionSubtitle = sectionSubtitle
        self.showsPageHeader = showsPageHeader
        self.header = AnyView(header())
        self.trailing = AnyView(trailing())
        self.content = content
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if showsPageHeader {
                    pageHeader
                }

                sectionHeader
                content()
            }
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                if let title {
                    Text(title)
                        .font(AppFont.largeTitle())
                        .foregroundStyle(.white)
                } else {
                    header
                }

                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.subheadline())
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            Spacer()

            trailing
        }
    }

    @ViewBuilder
    private var sectionHeader: some View {
        if sectionTitle != nil || sectionSubtitle != nil {
            VStack(alignment: .leading, spacing: 12) {
                if let sectionTitle {
                    Text(sectionTitle)
                        .font(AppFont.title())
                        .foregroundStyle(.white)
                }

                if let sectionSubtitle {
                    Text(sectionSubtitle)
                        .font(AppFont.footnote(weight: .medium))
                        .foregroundStyle(.white.opacity(0.66))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .matteCard(radius: 30)
        }
    }
}
