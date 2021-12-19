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

  var body: some View {
    Text("documents.count \(documents.count)")
    Text("events.count \(events.count)")
  }
}

//struct SongView_Previews: PreviewProvider {
//    static var previews: some View {
//        SongView()
//    }
//}
