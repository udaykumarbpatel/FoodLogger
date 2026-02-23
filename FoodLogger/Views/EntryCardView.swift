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
        VStack(spacing: 0) {
            // ── Header band ──────────────────────────────────────────────
            categoryHeaderBand

            // ── Card body ────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                // Description
                Text(entry.processedDescription)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(Color.brandSurface)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isExpanded ? nil : 2)
                    .minimumScaleFactor(0.85)
                    .accessibilityLabel(entry.processedDescription)

                if isExpanded {
                    expandedContent
                }

                // ── Footer row ───────────────────────────────────────────
                HStack(spacing: 6) {
                    timestampLabel
                    if entry.updatedAt != nil {
                        Text("· edited")
                            .font(.caption)
                            .foregroundStyle(Color.brandWarm.opacity(0.7))
                            .italic()
                            .accessibilityLabel("edited")
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(categoryColor.opacity(0.6))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(
                ZStack {
                    Color.brandVoid
                    categoryColor.opacity(0.07)
                }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHighlighted ? Color.brandAccent : categoryColor.opacity(0.25), lineWidth: isHighlighted ? 2 : 1)
        )
        .shadow(color: categoryColor.opacity(0.22), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.22)) {
                isExpanded.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
    }

    // MARK: - Category Header Band

    private var categoryHeaderBand: some View {
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
            HStack(spacing: 6) {
                Image(systemName: entry.category?.icon ?? "tag")
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
                Text((entry.category?.displayName ?? "Untagged").uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .kerning(0.8)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(categoryColor)
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
        .foregroundStyle(Color.brandSurface.opacity(0.4))
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        if let mediaURL = entry.mediaURL {
            thumbnailView(for: mediaURL)
        }
        if entry.rawInput != entry.processedDescription {
            Divider()
                .overlay(categoryColor.opacity(0.3))
            VStack(alignment: .leading, spacing: 4) {
                Text("Original")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .kerning(0.8)
                    .foregroundStyle(Color.brandSurface.opacity(0.3))
                    .textCase(.uppercase)
                    .accessibilityLabel("Original input")
                Text(entry.rawInput)
                    .font(.caption)
                    .foregroundStyle(Color.brandSurface.opacity(0.55))
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
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Meal photo")
            }
        }
    }
}
