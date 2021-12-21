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
    ZStack {
      if documents.first?.pitches != nil {
        ScrollView(.horizontal) {
          WaveView()
            .frame(width: scrollWidth)
        }
        HStack {
          NoteNamesView()
            .frame(width: 32)
          Spacer()
        }
      } else {
        Text("Please record some audio")
      }
    }
    .toolbar {
      let placement = toolbarPlacement()
      ToolbarItem(placement: placement) {
        if isProcessing {
          ProgressView()
        }
      }
      ToolbarItem(placement: placement) {
        Button(action: { isRecorderPresented = true }) {
          Text("Record")
        }
        .disabled(isProcessing)
      }
    }
    .sheet(isPresented: $isRecorderPresented) {
      RecorderView { url in
        url.map(processAudio)
        isRecorderPresented = false
      }
    }
  }

  func processAudio(_ url: URL) {
    guard let document = documents.first else { return }
    isProcessing = true
    DispatchQueue.global().async {
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
}

private func toolbarPlacement() -> ToolbarItemPlacement {
#if iOS
  return .bottomBar
#else
  return .automatic
#endif
}

//struct SongView_Previews: PreviewProvider {
//    static var previews: some View {
//        SongView()
//    }
//}
