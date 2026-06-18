//
//  HomeView.swift
//  KTPLIFE
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    let returnToAuth: () -> Void

    init(returnToAuth: @escaping () -> Void) {
        self.returnToAuth = returnToAuth
    }
    // this is required 
    var body: some View {
        VStack(spacing: 28) {
            HStack {
                headerLogo

                Spacer()

                addButton
            }

        
            Spacer()

            returnToAuthButton
        }
        .padding(22)
    }
    private var headerLogo: some View {
        Image("KTPLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(maxWidth: 180, maxHeight: 64, alignment: .leading)
            .shadow(color: .white.opacity(0.08), radius: 12, y: 4)
    }

    private var addButton: some View {
        Button(action: addItem) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.12), in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var returnToAuthButton: some View {
        Button(action: returnToAuth) {
            HStack(spacing: 12) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.10), in: Circle())

                Text("Back to Auth")
                    .font(.system(.headline, design: .rounded, weight: .bold))

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .matteCard()
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
}

private struct HomeActivityRow: View {
    let item: Item
    let delete: () -> Void

    var body: some View {
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

            Button(action: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.10), in: Circle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .matteCard()
    }
}

#Preview("Home") {
    HomeView(returnToAuth: {})
        .modelContainer(PreviewModelContainer.shared)
        .padding(20)
        .background(AppTab.home.theme.backgroundColor)
}
