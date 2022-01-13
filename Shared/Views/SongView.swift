//
//  SongView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 20/12/21.
//

import SwiftUI

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

  @State var isKeysPresented = false
  @State var isRecorderPresented = false
  @State var isProcessing = false
  @StateObject private var conductor = Current.conductor
  @State var isError = false
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
          }
        }
        HStack {
          Spacer()
          Group {
            Button(action: { isRecorderPresented = true }) {
              Text("Record")
            }
            Spacer()
          }
          Button(action: { playAudio() }) {
            Text("Play")
          }
          .contextMenu {
            Button(action: {
              documents.first?.autotuneEnabled = true
              playAudio()
            }) {
              if documents.first?.autotuneEnabled == true {
                Image(systemName: "checkmark")
              }
              Text("Tuned")
            }
            Button(action: {
              documents.first?.autotuneEnabled = false
              playAudio()
            }) {
              if documents.first?.autotuneEnabled == false {
                Image(systemName: "checkmark")
              }
              Text("Original")
            }
          }
          Spacer()
          Button(action: { stopAudio() }) {
            Text("Stop")
          }
          Spacer()
          Button(action: { isKeysPresented = true }) {
            Text(document.keyString)
          }
          Spacer()
          Button(action: { snapToKey(document) }) {
            Text("Snap")
          }
          Spacer()
        }
        Spacer()
      }
      .navigationTitle("Pitsh")
      .sheet(isPresented: $isRecorderPresented) {
        RecorderView { url in
          url.map(processAudio)
          isRecorderPresented = false
        }
      }
      .sheet(isPresented: $isProcessing) {
        VStack {
          Spacer()
          ProgressView()
          Spacer()
          Button("Cancel") {
            isProcessing = false
          }
          Spacer()
        }
      }
      .sheet(isPresented: $isKeysPresented) {
        KeysView(document)
      }
      .sheet(isPresented: $isError) {
        Text("Something went wrong.")
        Button("OK") {
          isError = false
        }
      }
      .onChange(of: isProcessing) { newValue in
        shouldContinue.value = newValue
      }
    } else {
      Text("No document error")
    }
  }

  private func processAudio(_ url: URL) {
    guard let document = documents.first,
          let destinationURL = document.audioFileURL else { return }
    isProcessing = true
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
              } catch {
                print(error)
                self.isError = true
              }
            }
          case .failure(let error):
            print(error)
            self.isError = true
          }
          self.isProcessing = false
        }
      }
    }
  }

  private func shiftAudioAndPlay() {
    guard let document = documents.first else { return }
    if document.needsPitchShift {
      isProcessing = true
      DispatchQueue.global(qos: .background).async {
        performAudioShift(shouldContinue: &shouldContinue.value, document: document) { result in
          DispatchQueue.main.async {
            isProcessing = false
            switch result {
            case .success(let finished):
              if finished {
                conductor.state = .playing(document.shiftedAudioFileURL)
              }
            case .failure(let error):
              print(error)
              self.isError = true
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
}

//struct SongView_Previews: PreviewProvider {
//    static var previews: some View {
//        SongView()
//    }
//}
