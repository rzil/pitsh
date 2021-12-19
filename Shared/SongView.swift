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

  var body: some View {
    VStack {
      Text("Record")
        .bold()
        .onTapGesture {
          isRecorderPresented = true
        }
      Text("documents.count \(documents.count)")
      Text("events.count \(events.count)")
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
    }
  }
}

//struct SongView_Previews: PreviewProvider {
//    static var previews: some View {
//        SongView()
//    }
//}
