import SwiftUI

struct EntryCardView: View {
    let entry: FoodEntry
    let isToday: Bool
    var isHighlighted: Bool = false
    @State private var isExpanded: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Left color bar
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(entry.category?.color ?? Color.clear)
                .frame(width: 4)
                .padding(.vertical, 10)

            // Card content
            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack(alignment: .center, spacing: 8) {
                    inputTypeIcon
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    categoryBadge

                    Spacer()

                    HStack(spacing: 5) {
                        timestampLabel

                        if entry.updatedAt != nil {
                            Text("· edited")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .italic()
                        }
                    }
                }

                // Description
                Text(entry.processedDescription)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? nil : 3)

                if isExpanded {
                    expandedContent
                }
            }
            .padding(14)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHighlighted ? Color.accentColor : .clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
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
        .foregroundStyle(.tertiary)
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
                Text(entry.rawInput)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            }
        }
    }

    // MARK: - Category Badge (tappable Menu)

    @ViewBuilder
    private var categoryBadge: some View {
        let current = entry.category
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
            if let cat = current {
                HStack(spacing: 4) {
                    Image(systemName: cat.icon)
                    Text(cat.displayName)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(cat.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(cat.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                    Text("Tag")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Input Type Icon

    private var inputTypeIcon: some View {
        let (name, label): (String, String) = {
            switch entry.inputType {
            case .text:  return ("text.alignleft", "Text entry")
            case .voice: return ("waveform", "Voice entry")
            case .image: return ("camera.fill", "Photo entry")
            }
        }()
        return Image(systemName: name)
            .accessibilityLabel(label)
    }
}
