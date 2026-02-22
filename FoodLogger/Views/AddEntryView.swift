import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import Speech

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var speechService = SpeechService()
    private let visionService = VisionService()
    private let descriptionBuilder = FoodDescriptionBuilder()

    @State private var selectedMode: InputMode = .text
    @State private var textInput: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSaving: Bool = false
    @State private var showCameraSheet: Bool = false
    @State private var speechError: String?

    enum InputMode: String, CaseIterable {
        case text = "Text"
        case voice = "Voice"
        case image = "Photo"

        var systemImage: String {
            switch self {
            case .text:  "text.alignleft"
            case .voice: "mic.fill"
            case .image: "camera.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Input Mode", selection: $selectedMode) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedMode {
                        case .text:  textInputView
                        case .voice: voiceInputView
                        case .image: imageInputView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveEntry() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave || isSaving)
                }
            }
            .sheet(isPresented: $showCameraSheet) {
                CameraPickerView(image: $selectedImage)
            }
            .onDisappear {
                if speechService.isRecording {
                    speechService.stopRecording()
                }
            }
            .task {
                if speechService.authorizationStatus == .notDetermined {
                    await speechService.requestAuthorization()
                }
            }
        }
    }

    // MARK: - Text Mode

    private var textInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What did you eat?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $textInput)
                .frame(minHeight: 140)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
        }
    }

    // MARK: - Voice Mode

    private var voiceInputView: some View {
        VStack(spacing: 24) {
            if let error = speechError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            ZStack {
                Circle()
                    .fill(speechService.isRecording ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.1))
                    .frame(width: 88, height: 88)
                    .scaleEffect(speechService.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                               value: speechService.isRecording)

                Button {
                    toggleRecording()
                } label: {
                    Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(speechService.isRecording ? .red : .accentColor)
                        .frame(width: 72, height: 72)
                        .background(
                            Circle().fill(speechService.isRecording
                                          ? Color.red.opacity(0.15)
                                          : Color.accentColor.opacity(0.15))
                        )
                }
            }

            Text(speechService.isRecording ? "Recording…" : "Tap to record")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !speechService.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Transcript")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    Text(speechService.transcript)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.top, 8)
    }

    private func toggleRecording() {
        speechError = nil
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            do {
                try speechService.startRecording()
            } catch {
                speechError = error.localizedDescription
            }
        }
    }

    // MARK: - Image Mode

    private var imageInputView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
                }

                Button {
                    showCameraSheet = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .buttonStyle(.plain)

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 160)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("No photo selected")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
            }
        }
    }

    // MARK: - Save

    private var canSave: Bool {
        switch selectedMode {
        case .text:  return !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .voice: return !speechService.transcript.isEmpty
        case .image: return selectedImage != nil
        }
    }

    private func saveEntry() async {
        isSaving = true
        defer { isSaving = false }

        if speechService.isRecording {
            speechService.stopRecording()
            try? await Task.sleep(for: .milliseconds(300))
        }

        let rawInput: String
        let inputType: InputType
        let processedDescription: String
        var mediaURL: URL?

        switch selectedMode {
        case .text:
            inputType = .text
            rawInput = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
            processedDescription = descriptionBuilder.buildDescription(fromText: rawInput)

        case .voice:
            inputType = .voice
            rawInput = speechService.transcript
            processedDescription = descriptionBuilder.buildDescription(fromTranscript: rawInput)

        case .image:
            inputType = .image
            rawInput = "Photo"
            if let image = selectedImage {
                let labels = (try? await visionService.classifyImage(image)) ?? []
                processedDescription = descriptionBuilder.buildDescription(fromVisionLabels: labels)
                mediaURL = try? saveImageToDocuments(image)
            } else {
                processedDescription = "Photo"
            }
        }

        let entry = FoodEntry(
            date: Calendar.current.startOfDay(for: Date()),
            rawInput: rawInput,
            inputType: inputType,
            processedDescription: processedDescription,
            mediaURL: mediaURL
        )
        modelContext.insert(entry)

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        dismiss()
    }

    private func saveImageToDocuments(_ image: UIImage) throws -> URL {
        let filename = "\(UUID().uuidString).jpg"
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsDir.appendingPathComponent(filename)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw ImageSaveError.compressionFailed
        }
        try data.write(to: fileURL)
        // Store only the filename component — EntryCardView reconstructs the full path
        return URL(string: filename)!
    }

    enum ImageSaveError: Error {
        case compressionFailed
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        nonisolated func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            Task { @MainActor in
                self.parent.image = image
                self.parent.dismiss()
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            Task { @MainActor in
                self.parent.dismiss()
            }
        }
    }
}
