import SwiftUI

struct EntryCardView: View {
    let entry: FoodEntry
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                inputTypeIcon
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(entry.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

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
        // relativeURL is stored as a plain filename URL (e.g. "uuid.jpg"),
        // use absoluteString to get the bare filename without a leading slash.
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
