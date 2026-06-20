//
//  SharedViews.swift
//  KTPLIFE
//

import SwiftUI

struct KTPLogoMark: View {
    var maxWidth: CGFloat = 220
    var maxHeight: CGFloat = 78
    var alignment: Alignment = .center

    var body: some View {
        Image("KTPLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: alignment)
    }
}

struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.headline())
                .foregroundStyle(.white)

            Text(message)
                .font(AppFont.subheadline())
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .matteCard(radius: 28)
    }
}

extension View {
    func matteCard(radius: CGFloat = 26) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }
}
