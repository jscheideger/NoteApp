//
//  ContentView.swift
//  NoteApp
//
//  Created by Jesten Scheideger on 2/14/25.
//

import SwiftUI
import NaturalLanguage


struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var isCompleted: Bool
    
    init(id: UUID = UUID(), title: String, content: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.isCompleted = isCompleted
    }
}

class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = [] {
        didSet {
            saveNotes()
        }
    }
    
    private let saveKey = "SavedNotes"
    
    init() {
        loadNotes()
    }
    
    func addNote(title: String, content: String) {
        let correctedTitle = autocorrect(text: title)
        let correctedContent = autocorrect(text: content)
        let newNote = Note(title: title, content: content)
        notes.append(newNote)
    }
    
    func updateNote(note: Note, title: String, content: String) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].title = autocorrect(text: title)
            notes[index].content = autocorrect(text: content)
        }
    }
    
    func toggleCompletion(for note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isCompleted.toggle()
        }
    }
    
    func deleteNotes(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
    }
    
    private func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadNotes() {
        if let savedData = UserDefaults.standard.data(forKey: saveKey),
           let decodedNotes = try? JSONDecoder().decode([Note].self, from: savedData) {
            notes = decodedNotes
        }
    }
    
    private func autocorrect(text: String) -> String {
            let tagger = NLTagger(tagSchemes: [.lemma])
            tagger.string = text
            var correctedText = ""
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: [.omitPunctuation, .omitWhitespace]) { tag, tokenRange in
                if let tag = tag?.rawValue {
                    correctedText += tag + " "
                } else {
                    correctedText += text[tokenRange] + " "
                }
                return true
            }
            return correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

struct ContentView: View {
    @StateObject private var viewModel = NotesViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.notes) { note in
                    NavigationLink(destination: NoteDetailView(viewModel: viewModel, note: note)) {
                        HStack{
                            if note.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text(note.title)
                                .font(.headline)
                                .strikethrough(note.isCompleted, color: .gray)
                            Text(note.content)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: viewModel.deleteNotes)
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Add", destination: AddEditNoteView(viewModel: viewModel))
                }
            }
        }
    }
}

struct NoteDetailView: View {
    @ObservedObject var viewModel: NotesViewModel
    var note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.title)
                .font(.largeTitle)
                .bold()
            Text(note.content)
                .font(.body)
            Button(action: {
                viewModel.toggleCompletion(for: note)
            }) {
                Text(note.isCompleted ? "Mark as Incomplete" : "Mark as Complete")
                    .padding()
                    .background(note.isCompleted ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 20)
            Spacer()
        }
        .padding()
        .navigationTitle("Note Details")
        .toolbar {
            NavigationLink("Edit", destination: AddEditNoteView(viewModel: viewModel, note: note))
        }
    }
}

struct AddEditNoteView: View {
    @ObservedObject var viewModel: NotesViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var note: Note?
    @State private var title: String
    @State private var content: String
    
    init(viewModel: NotesViewModel, note: Note? = nil) {
        self.viewModel = viewModel
        self.note = note
        _title = State(initialValue: note?.title ?? "")
        _content = State(initialValue: note?.content ?? "")
    }
    
    var body: some View {
        Form {
            Section(header: Text("Title")) {
                TextField("Enter title", text: $title)
            }
            Section(header: Text("Content")) {
                TextEditor(text: $content)
                    .frame(height: 200)
            }
        }
        .navigationTitle(note == nil ? "Add Note" : "Edit Note")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    if let note = note {
                        viewModel.updateNote(note: note, title: title, content: content)
                    } else {
                        viewModel.addNote(title: title, content: content)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
