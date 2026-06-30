//
//  HomeView.swift
//  KTPLIFE
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    
    let returnToSignup: () -> Void
    
    init(returnToSignup: @escaping () -> Void) {
        self.returnToSignup = returnToSignup
    }
    // this is required
    var body: some View {
        VStack(spacing: 28) {
            
            Spacer()
            returnToSignupButton
        }
        .padding(22)
    }
    
    
    
    
    private var returnToSignupButton: some View {
        Button(action: returnToSignup) {
            HStack(spacing: 12) {
                Text("Back to Sign Up")
                    .font(AppFont.headline())
                
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .matteCard()
    }
}

 
private struct HomeActivityRow: View {
    let item: Item
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.timestamp, format: .dateTime.month(.abbreviated).day().year())
                    .font(AppFont.headline())
                    .foregroundStyle(.white)

                Text(item.timestamp, format: .dateTime.hour().minute())
                    .font(AppFont.subheadline())
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Button(action: delete) {
                Text("Delete")
                    .font(AppFont.footnote(weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppSurfaceColor.primaryControl, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .matteCard()
    }
}

#Preview("Home") {
    HomeView(returnToSignup: {})
        .modelContainer(PreviewModelContainer.shared)
        .padding(20)
        .background(AppTab.home.theme.previewBackground())
}
