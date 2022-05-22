//
//  SongView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 20/12/21.
//

import SwiftUI

private let minimumDuration: Double = 1

struct SongView: View {

  // This class is used to pass a flag into
  // background threads. This can be used to
  // end the task running on the thread.
  private class ShouldContinue {
    var value: Bool = false
  }

  @Environment(\.managedObjectContext) var managedObjectContext

  @FetchRequest(
    entity: PitshDocument.entity(),
    sortDescriptors: []
  ) var documents: FetchedResults<PitshDocument>

  private var document: PitshDocument {
    documents.first!
  }

  @StateObject private var conductor = Current.conductor
  @StateObject private var viewModel = SongViewModel()
  @State private var isPresentingError = false
  private var shouldContinue = ShouldContinue()

  private let secondsPerScreen: Double = 5
  private var scrollWidth: CGFloat {
    var width: CGFloat = 1000
    guard let document = documents.first,
          let pitches = document.pitches
    else { return 0 }
    let framesPerScreen = document.audioSampleRate / Double(document.stepSize) * secondsPerScreen
    if (Double(pitches.count) > framesPerScreen) {
      width *= CGFloat(Double(pitches.count) / framesPerScreen)
    }
    return width
  }

  var recordButton: some View {
    Button(action: { viewModel.isRecorderPresented = true }) {
      Text("Record")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .disabled(!conductor.state.isStopped)
  }

  var playButton: some View {
    Button(action: { playAudio() }) {
      Text("Play")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .disabled(!conductor.state.isStopped)
    .contextMenu {
      Button(action: {
        documents.first?.autotuneEnabled = true
        Current.coreData.persistentContainer().saveContext()
        playAudio()
      }) {
        if documents.first?.autotuneEnabled == true {
          Image(systemName: "checkmark")
        }
        Text("Tuned")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      Button(action: {
        documents.first?.autotuneEnabled = false
        Current.coreData.persistentContainer().saveContext()
        playAudio()
      }) {
        if documents.first?.autotuneEnabled == false {
          Image(systemName: "checkmark")
        }
        Text("Original")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    }
  }

  var stopButton: some View {
    Button(action: { stopAudio() }) {
      Text("Stop")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .disabled(conductor.state.isStopped)
  }

  var keyButton: some View {
    Button(action: { viewModel.isKeysPresented = true }) {
      Text(document.keyString)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .disabled(!conductor.state.isStopped)
  }

  var snapButton: some View {
    Button(action: { snapToKey(document) }) {
      Text("Snap")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .disabled(!conductor.state.isStopped)
  }

  var shareButton: some View {
    Button(action: { viewModel.isSharePresented = true }) {
      Image(systemName: "square.and.arrow.up")
    }
    .buttonStyle(.bordered)
    .disabled(!conductor.state.isStopped || document.pitches == nil)
    .sheet(isPresented: $viewModel.isSharePresented) {
      ActivityViewController(activityItems: (document.shiftedAudioFileURL.map { [$0] } ?? []) )
    }
  }

  var processingSheet: some View {
    VStack(alignment: .center, spacing: 16) {
      Spacer()
      Text("Processing")
        .font(.title)
      Spacer()
      ProgressView()
      Spacer()
      Button(action: { viewModel.isProcessing = false }) {
        Text("Cancel")
          .frame(maxWidth: .infinity, maxHeight: 60)
      }
      .buttonStyle(.bordered)
      Spacer()
    }
    .padding()
  }

  var errorSheet: some View {
    VStack(alignment: .center, spacing: 16) {
      Text("Something went wrong.")
        .font(.title)
      if let message = viewModel.error?.localizedDescription {
        Text(message)
          .font(.callout)
      }
      Button(action: { isPresentingError = false }) {
        Text("Ok")
          .frame(maxWidth: .infinity, maxHeight: 60)
      }
      .buttonStyle(.bordered)
    }
    .padding()
  }

  var body: some View {
    if let document = documents.first {
      VStack {
        ZStack {
          if document.pitches != nil {
            ScrollView(.horizontal) {
              ZStack {
                WaveView(document: document)
                NotesView()
                GeometryReader { geometry in
                  let width = geometry.size.width
                  Rectangle()
                    .foregroundColor(.gray)
                    .frame(width: 1)
                    .offset(x: conductor.state.isPlaying ? width : 0, y: 0)
                    .animation(
                      .linear(duration: conductor.state.isPlaying ? conductor.player.duration : 0),
                      value: conductor.state.isPlaying)
                }
              }
              .frame(width: scrollWidth)
            }
            HStack {
              NoteNamesView(document: document)
                .frame(width: 32)
                .clipped()
              Spacer()
            }
          } else {
            Text("Please record some audio")
              .font(.title)
              .padding()
          }
        }
        HStack {
          Spacer()
          Group {
            recordButton
            Spacer()
          }
          Group {
            playButton
            Spacer()
          }
          Group {
            stopButton
            Spacer()
          }
          Group {
            keyButton
            Spacer()
          }
          Group {
            snapButton
            Spacer()
          }
          Group {
            shareButton
            Spacer()
          }
        }
        Spacer()
      }
      .navigationTitle("Pitsh")
      .sheet(isPresented: $viewModel.isRecorderPresented) {
        RecorderView { result in
          viewModel.isRecorderPresented = false
          if let (url, duration) = result {
            if duration > minimumDuration {
              processAudio(url)
            } else {
              self.viewModel.error = PitshError("Recording duration too short")
            }
          }
        }
      }
      .sheet(isPresented: $viewModel.isProcessing) {
        processingSheet
      }
      .sheet(isPresented: $viewModel.isKeysPresented) {
        KeysView(document)
      }
      .sheet(isPresented: $isPresentingError) {
        errorSheet
      }
      .onReceive(viewModel.$isProcessing, perform: { newValue in
        shouldContinue.value = newValue
      })
      .onReceive(viewModel.$error) { newValue in
        isPresentingError = (newValue != nil)
      }
    } else {
      Text("No document exists")
    }
  }

  private func processAudio(_ url: URL) {
    guard let document = documents.first,
          let destinationURL = document.audioFileURL else { return }
    viewModel.isProcessing = true
    DispatchQueue.global(qos: .background).async {
      document.performAutocorrelation(shouldContinue: &shouldContinue.value, audioFileURL: url) { result in
        DispatchQueue.main.async {
          switch result {
          case .success(let finished):
            if finished {
              do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: destinationURL.path) {
                  try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: url, to: destinationURL)
                document.needsPitchShift = true
                Current.coreData.persistentContainer().saveContext()
              } catch {
                self.viewModel.error = error
              }
            }
          case .failure(let error):
            self.viewModel.error = error
          }
          self.viewModel.isProcessing = false
        }
      }
    }
  }

  private func shiftAudioAndPlay() {
    guard let document = documents.first else { return }
    if document.needsPitchShift {
      viewModel.isProcessing = true
      DispatchQueue.global(qos: .background).async {
        performAudioShift(shouldContinue: &shouldContinue.value, document: document) { result in
          DispatchQueue.main.async {
            viewModel.isProcessing = false
            switch result {
            case .success(let finished):
              if finished {
                conductor.state = .playing(document.shiftedAudioFileURL)
              }
            case .failure(let error):
              self.viewModel.error = error
            }
          }
        }
      }
    } else {
      conductor.state = .playing(document.shiftedAudioFileURL)
    }
  }

  private func playOriginal() {
    guard let document = documents.first else { return }
    conductor.state = .playing(document.audioFileURL)
  }

  private func playAudio() {
    guard let document = documents.first else { return }
    if document.autotuneEnabled {
      shiftAudioAndPlay()
    } else {
      playOriginal()
    }
  }

  private func stopAudio() {
    conductor.state = .stopped
  }
}

private func performAudioShift(
  shouldContinue: inout Bool,
  document: PitshDocument,
  completion: @escaping (Result<Bool,Error>) -> ()) {
  guard let audioURL = document.audioFileURL,
        let shiftedAudioURL = document.shiftedAudioFileURL,
        let eventsSorted = document.eventsSorted
  else {
    completion(.failure(PitshError("Document missing parameters")))
    return
  }
  do {
    let (floatData, sampleRate) = try audioURL.readAudioFile()
    guard let pitchShifter = PitchShifter(sampleRate: Float(sampleRate))
    else {
      completion(.failure(PitshError("Failed to create pitch shifter")))
      return
    }
    pitchShifter.pitchTrack = document.frequencies
    pitchShifter.powerTrack = document.powers
    pitchShifter.finalPitchTrack = pitchShifter.pitchTrack
    for ev in eventsSorted {
      let start = Int(ev.start)
      let end = Int(ev.end)
      let f = pow(2, (ev.effectivePitch + 3) / 12) * 55
      for i in start ..< end {
        pitchShifter.finalPitchTrack?[i] = f
      }
    }
    if let shiftedAudio = pitchShifter.process(shouldContinue: &shouldContinue, pitchShift: 1, indata: floatData) {
      try shiftedAudioURL.writeAudioFile(shiftedAudio, sampleRate: sampleRate)
      document.needsPitchShift = false
      Current.coreData.persistentContainer().saveContext()
      completion(.success(true))
    } else {
      completion(.success(false))
    }
  } catch {
    completion(.failure(error))
  }
}

private func snapToKey(_ document: PitshDocument) {
  document.eventsSorted?.forEach { $0.snapToKey() }
  document.needsPitchShift = true
  Current.coreData.persistentContainer().saveContext()
}

final class SongViewModel: ObservableObject {
  @Published var isKeysPresented = false
  @Published var isRecorderPresented = false
  @Published var isSharePresented = false
  @Published var isProcessing = false
  @Published var error: Error?
}
