import SwiftUI

struct EntryCardView: View {
    let entry: FoodEntry
    let isToday: Bool
    var isHighlighted: Bool = false
    @State private var isExpanded: Bool = false

    private static let nilCategoryColor = Color(hex: "#95A5A6")

    private var categoryColor: Color {
        entry.category?.color ?? Self.nilCategoryColor
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left color bar — matches category pill color
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(categoryColor)
                .frame(width: 4)
                .padding(.vertical, 10)

            // Card content
            VStack(alignment: .leading, spacing: 8) {
                // Top row: category pill (content-sized) + timestamp
                HStack(alignment: .center) {
                    categoryPill
                    Spacer()
                    HStack(spacing: 4) {
                        timestampLabel
                        if entry.updatedAt != nil {
                            Text("· edited")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                                .accessibilityLabel("edited")
                        }
                    }
                }

                // Description
                Text(entry.processedDescription)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isExpanded ? nil : 2)
                    .minimumScaleFactor(0.85)
                    .accessibilityLabel(entry.processedDescription)

                if isExpanded {
                    expandedContent
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            ZStack {
                Color(UIColor.secondarySystemGroupedBackground)
                categoryColor.opacity(0.06)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHighlighted ? Color.brandAccent : .clear, lineWidth: 2)
        )
        .shadow(color: categoryColor.opacity(0.15), radius: 6, x: 0, y: 3)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
    }

    // MARK: - Category Pill (content-sized, tappable Menu)

    private var categoryPill: some View {
        Menu {
            ForEach(MealCategory.allCases, id: \.self) { cat in
                Button {
                    entry.category = cat
                } label: {
                    Label(cat.displayName, systemImage: cat.icon)
                }
            }
            Divider()
            Button {
                entry.category = nil
            } label: {
                Label("Remove Tag", systemImage: "xmark.circle")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: entry.category?.icon ?? "tag")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
                Text(entry.category?.displayName ?? "Tag")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(categoryColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(categoryColor.opacity(0.15))
            .clipShape(Capsule())
        }
        .accessibilityLabel("Category: \(entry.category?.displayName ?? "None"). Double tap to change.")
    }

    // MARK: - Timestamp

    private var timestampLabel: some View {
        Group {
            if isToday {
                Text(entry.createdAt, style: .relative)
            } else {
                Text(entry.createdAt, style: .time)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        if let mediaURL = entry.mediaURL {
            thumbnailView(for: mediaURL)
        }
        if entry.rawInput != entry.processedDescription {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Original")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .accessibilityLabel("Original input")
                Text(entry.rawInput)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(entry.rawInput)
            }
        }
    }

    private func thumbnailView(for relativeURL: URL) -> some View {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = relativeURL.absoluteString
        let absoluteURL = docsDir.appendingPathComponent(filename)
        return Group {
            if let uiImage = UIImage(contentsOfFile: absoluteURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Meal photo")
            }
        }
    }
}
