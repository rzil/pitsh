//
//  SongView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 20/12/21.
//

import SwiftUI

struct SongView: View {
  @Environment(\.managedObjectContext) var managedObjectContext

  @FetchRequest(
    entity: PitshDocument.entity(),
    sortDescriptors: []
  ) var documents: FetchedResults<PitshDocument>

  @FetchRequest(
    entity: PitshEvent.entity(),
    sortDescriptors: [
      NSSortDescriptor(keyPath: \PitshEvent.start, ascending: true)
    ]
  ) var events: FetchedResults<PitshEvent>

  @State var isRecorderPresented = false
  @State var isProcessing = false

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
    VStack {
      ZStack {
        if documents.first?.pitches != nil {
          ScrollView(.horizontal) {
            ZStack {
              WaveView()
              NotesView()
            }
            .frame(width: scrollWidth)
          }
          HStack {
            NoteNamesView()
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
        Button(action: { isRecorderPresented = true }) {
          Text("Record")
        }
        Spacer()
        Button(action: { shiftAudioAndPlay() }) {
          Text("Play")
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
      ProgressView()
    }
  }

  private func processAudio(_ url: URL) {
    guard let document = documents.first else { return }
    isProcessing = true
    DispatchQueue.global(qos: .background).async {
      do {
        if let destinationURL = document.audioFileURL {
          let fileManager = FileManager.default
          if fileManager.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
          }
          try FileManager.default.moveItem(at: url, to: destinationURL)
          print("*** tuning")
          do {
            try document.performAutocorrelation { error in
              print("*** done tuning: \(error?.localizedDescription ?? "no errors")")
              print("*** event count \(document.eventsSorted?.count ?? -1)")
            }
          } catch {
            print(error)
          }
        }
      } catch {
        print(error)
      }
      self.isProcessing = false
    }
  }

  private func shiftAudioAndPlay() {
    guard let document = documents.first else { return }
    if document.needsPitchShift {
      isProcessing = true
      performAudioShift(document: document) {
        isProcessing = false
        if let error = $0 {
          print(error)
        } else {
          // play shifted audio
        }
      }
    } else {
      // play shifted audio
    }
  }
}

private func performAudioShift(document: PitshDocument, completion: @escaping (Error?) -> ()) {
  guard let audioURL = document.audioFileURL,
        let shiftedAudioURL = document.shiftedAudioFileURL,
        let eventsSorted = document.eventsSorted
  else {
    completion(PitshError("Document missing parameters"))
    return
  }
  DispatchQueue.global(qos: .background).async {
    do {
      let (floatData, sampleRate) = try audioURL.readAudioFile()
      guard let pitchShifter = PitchShifter(sampleRate: Float(sampleRate))
      else {
        completion(PitshError("Failed to create pitch shifter"))
        return
      }
      print("*** pitch shifting")
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
      let shiftedAudio = pitchShifter.process(pitchShift: 1, indata: floatData)
      print("*** done with pitch shift")
      try shiftedAudioURL.writeAudioFile(shiftedAudio, sampleRate: sampleRate)
      document.needsPitchShift = false
      completion(nil)
    } catch {
      completion(error)
    }
  }
}

//struct SongView_Previews: PreviewProvider {
//    static var previews: some View {
//        SongView()
//    }
//}
