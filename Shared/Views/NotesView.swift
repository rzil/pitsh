//
//  NotesView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 22/12/2021.
//

import SwiftUI

struct NotesView: View {
  @FetchRequest(
    entity: PitshEvent.entity(),
    sortDescriptors: [
      NSSortDescriptor(keyPath: \PitshEvent.start, ascending: true)
    ]
  ) var events: FetchedResults<PitshEvent>

  var body: some View {
    GeometryReader { geometry in
      if let document = events.first?.relatedDocument,
         let pitchesCount = document.pitches?.count {
        let width = geometry.size.width
        let height = geometry.size.height
        let (smallest, biggest) = document.visiblePitchRange
        let range = biggest - smallest
        let noteHeight = height / CGFloat(range)
        ForEach(events) { event in
          let start_x = CGFloat(event.start) / CGFloat(pitchesCount)
          let end_x = CGFloat(event.end) / CGFloat(pitchesCount)
          let mid_x = 0.5 * (start_x + end_x)
          let noteWidth = width * (end_x - start_x)
          let xpos = width * mid_x - 0.5 * noteWidth
          let ypos = height * (1 - CGFloat(((event.avPitch + event.pitchShift)-smallest)/range)) - 0.5 * noteHeight
          NoteView(event: event)
            .offset(
              x: xpos,
              y: ypos
            )
            .frame(
              width: noteWidth,
              height: noteHeight
            )
        }
      }
    }
  }
}

//struct NotesView_Previews: PreviewProvider {
//    static var previews: some View {
//        NotesView()
//    }
//}
