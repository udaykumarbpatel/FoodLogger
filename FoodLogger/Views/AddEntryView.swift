import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import Speech

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let forDate: Date
    let editingEntry: FoodEntry?

    @State private var speechService = SpeechService()
    private let visionService = VisionService()
    private let descriptionBuilder = FoodDescriptionBuilder()
    private let categoryService = CategoryDetectionService()

    // Mode & basic input
    @State private var selectedMode: InputMode
    @State private var textInput: String
    @State private var selectedCategory: MealCategory?

    // Photo state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCameraSheet: Bool = false

    // Save state
    @State private var isSaving: Bool = false

    // --- Part 2: AI-processing state ---
    // Voice processing
    @State private var speechError: String?
    @State private var voiceEditableDescription: String = ""

    // Image processing
    @State private var imageEditableDescription: String = ""
    @State private var isProcessingImage: Bool = false
    @State private var storedVisionLabels: [String] = []   // kept for category auto-detect

    // Permission denied alert
    @State private var showPermissionAlert: Bool = false
    @State private var permissionAlertTitle: String = ""
    @State private var permissionAlertMessage: String = ""

    // MARK: - Input Mode

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

    // MARK: - Init

    init(
        forDate: Date = Calendar.current.startOfDay(for: Date()),
        editingEntry: FoodEntry? = nil
    ) {
        self.forDate = forDate
        self.editingEntry = editingEntry
        if let entry = editingEntry {
            _selectedMode = State(initialValue: .text)
            _textInput = State(initialValue: entry.processedDescription)
            _selectedCategory = State(initialValue: entry.category)
        } else {
            _selectedMode = State(initialValue: .text)
            _textInput = State(initialValue: "")
            _selectedCategory = State(initialValue: nil)
        }
    }

    private var isEditMode: Bool { editingEntry != nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !isEditMode {
                    Picker("Input Mode", selection: $selectedMode) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    Divider()
                }

                ScrollView {
                    VStack(spacing: 20) {
                        if isEditMode {
                            editDescriptionView
                        } else {
                            switch selectedMode {
                            case .text:  textInputView
                            case .voice: voiceInputView
                            case .image: imageInputView
                            }
                        }
                        categoryPickerSection
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditMode ? "Edit Entry" : "Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await saveEntry() } }
                        .fontWeight(.semibold)
                        .disabled(!canSave || isSaving)
                }
            }
            .sheet(isPresented: $showCameraSheet) {
                CameraPickerView(image: $selectedImage)
            }
            .onDisappear {
                if speechService.isRecording { speechService.stopRecording() }
            }
            .task {
                if speechService.authorizationStatus == .notDetermined {
                    await speechService.requestAuthorization()
                }
            }
            // Trigger NLTagger when recording stops
            .onChange(of: speechService.isRecording) { wasRecording, isRecording in
                if wasRecording && !isRecording {
                    Task { await processVoiceTranscript() }
                }
            }
            // Trigger Vision when a new image is selected
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    Task { await processImage(image) }
                }
            }
            .alert(permissionAlertTitle, isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(permissionAlertMessage)
            }
        }
    }

    // MARK: - Edit Mode

    private var editDescriptionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
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

    // MARK: - Category Picker

    private var categoryPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meal Type")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Meal Type", selection: $selectedCategory) {
                Text(isEditMode ? "None" : "Auto-detect")
                    .tag(Optional<MealCategory>.none)
                ForEach(MealCategory.allCases, id: \.self) { cat in
                    Label(cat.displayName, systemImage: cat.icon)
                        .tag(Optional<MealCategory>.some(cat))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
        VStack(spacing: 20) {
            // Permission / generic error
            if let error = speechError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // Mic button
            ZStack {
                Circle()
                    .fill(speechService.isRecording
                          ? Color.red.opacity(0.15)
                          : Color.accentColor.opacity(0.1))
                    .frame(width: 88, height: 88)
                    .scaleEffect(speechService.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                               value: speechService.isRecording)

                Button { toggleRecording() } label: {
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

            // Status label
            Group {
                if speechService.isRecording {
                    Text("Recording…")
                } else if voiceEditableDescription.isEmpty {
                    Text("Tap to record")
                } else {
                    Text("Tap to record again")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Live / completed transcript
            if !speechService.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcript")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    Text(speechService.transcript)
                        .font(.caption)
                        .foregroundStyle(voiceEditableDescription.isEmpty ? .primary : .tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Editable transcript — shown after recording stops
            if !voiceEditableDescription.isEmpty {
                editableDescriptionField(text: $voiceEditableDescription)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Image Mode

    private var imageInputView: some View {
        VStack(spacing: 16) {
            // Photo picker + camera buttons
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

                Button { openCamera() } label: {
                    Label("Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .buttonStyle(.plain)

            // Image preview or placeholder
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 140)
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

            // Processing indicator
            if isProcessingImage {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.85)
                    Text("Analyzing photo…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Editable description — shown after Vision processing
            if !imageEditableDescription.isEmpty && !isProcessingImage {
                editableDescriptionField(text: $imageEditableDescription)
            }
        }
    }

    // MARK: - Shared: Editable Description Field

    private func editableDescriptionField(text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Description — edit before saving", systemImage: "pencil.line")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextEditor(text: text)
                .frame(minHeight: 80)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                )
        }
    }

    // MARK: - canSave

    private var canSave: Bool {
        if isEditMode {
            return !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        switch selectedMode {
        case .text:
            return !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .voice:
            return !voiceEditableDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image:
            return !imageEditableDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !isProcessingImage
        }
    }

    // MARK: - Save

    private func saveEntry() async {
        isSaving = true
        defer { isSaving = false }

        // EDIT MODE
        if let entry = editingEntry {
            entry.processedDescription = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.category = selectedCategory
            entry.updatedAt = Date()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
            return
        }

        // CREATE MODE
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
            // Use the user-edited description (already processed by NLTagger)
            processedDescription = voiceEditableDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        case .image:
            inputType = .image
            if let image = selectedImage {
                let savedURL = try? saveImageToDocuments(image)
                mediaURL = savedURL
                rawInput = savedURL?.absoluteString ?? "photo"
            } else {
                rawInput = "photo"
            }
            // Use the user-edited description (already processed by Vision)
            processedDescription = imageEditableDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let hour = Calendar.current.component(.hour, from: Date())
        // storedVisionLabels is populated by processImage(); empty for text/voice
        let category: MealCategory? = selectedCategory ?? categoryService.detect(
            hour: hour,
            description: processedDescription,
            visionLabels: storedVisionLabels
        )

        let entry = FoodEntry(
            date: forDate,
            rawInput: rawInput,
            inputType: inputType,
            processedDescription: processedDescription,
            mediaURL: mediaURL,
            category: category
        )
        modelContext.insert(entry)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    // MARK: - AI Processing

    private func processVoiceTranscript() async {
        guard !speechService.transcript.isEmpty else { return }
        voiceEditableDescription = speechService.transcript
    }

    private func processImage(_ image: UIImage) async {
        isProcessingImage = true
        imageEditableDescription = ""
        storedVisionLabels = []
        let labels = (try? await visionService.classifyImage(image)) ?? []
        storedVisionLabels = labels
        imageEditableDescription = descriptionBuilder.buildDescription(fromVisionLabels: labels)
        isProcessingImage = false
    }

    // MARK: - Recording

    private func toggleRecording() {
        speechError = nil
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            voiceEditableDescription = ""   // reset for new recording
            do {
                try speechService.startRecording()
            } catch {
                let speechDenied = speechService.authorizationStatus == .denied
                    || speechService.authorizationStatus == .restricted
                let micDenied = AVAudioSession.sharedInstance().recordPermission == .denied
                if micDenied {
                    showPermissionDenied(title: "Microphone Access Needed",
                        message: "FoodLogger needs microphone access to record meal descriptions. Enable it in Settings.")
                } else if speechDenied {
                    showPermissionDenied(title: "Speech Recognition Access Needed",
                        message: "FoodLogger needs speech recognition to transcribe your recordings. Enable it in Settings.")
                } else {
                    speechError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Camera Permission

    private func openCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCameraSheet = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        self.showCameraSheet = true
                    } else {
                        self.showPermissionDenied(
                            title: "Camera Access Needed",
                            message: "FoodLogger needs camera access to photograph your meals. Enable it in Settings."
                        )
                    }
                }
            }
        default:
            showPermissionDenied(
                title: "Camera Access Needed",
                message: "FoodLogger needs camera access to photograph your meals. Enable it in Settings."
            )
        }
    }

    private func showPermissionDenied(title: String, message: String) {
        permissionAlertTitle = title
        permissionAlertMessage = message
        showPermissionAlert = true
    }

    // MARK: - Image Storage

    private func saveImageToDocuments(_ image: UIImage) throws -> URL {
        let filename = "\(UUID().uuidString).jpg"
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsDir.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw ImageSaveError.compressionFailed
        }
        try data.write(to: fileURL)
        // Store bare filename; reconstructed at read time via .absoluteString
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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

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
            Task { @MainActor in self.parent.dismiss() }
        }
    }
}
