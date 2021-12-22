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

  @State var draggedEvent: (PitshEvent,CGFloat)?

  var body: some View {
    GeometryReader { geometry in
      ForEach(events) { event in
        if let frame = frameForEvent(event, geometry: geometry) {
          NoteView(event: event)
            .onTapGesture(perform: {
              event.isSelected.toggle()
            })
            .highPriorityGesture(
              DragGesture()
                .onEnded({ value in
                  draggedEvent = nil
                  if let shift = event.relatedDocument?.convertVerticalShiftToPitch(
                    from: value.translation.height,
                    containerHeight: geometry.size.height
                  ) {
                    event.pitchShift += shift
                  }
                })
                .onChanged { value in
                  draggedEvent = (event, value.translation.height)
                }
            )
            .offset(
              x: frame.minX,
              y: frame.minY
            )
            .frame(
              width: frame.width,
              height: frame.height
            )
        }
      }

      if let (event, yOffset) = draggedEvent {
        if let frame = frameForEvent(event, geometry: geometry) {
          NoteView(event: event)
            .opacity(0.5)
            .offset(
              x: frame.minX,
              y: frame.minY + yOffset
            )
            .frame(
              width: frame.width,
              height: frame.height
            )
        }
      }
    }
  }
}

private func frameForEvent(_ event: PitshEvent, geometry: GeometryProxy) -> CGRect? {
  guard let document = event.relatedDocument,
        let pitchesCount = document.pitches?.count,
        pitchesCount > 0
  else { return nil }
  let width = geometry.size.width
  let height = geometry.size.height
  let (smallest, biggest) = document.visiblePitchRange
  let range = biggest - smallest
  let noteHeight = height / CGFloat(range)
  let start_x = CGFloat(event.start) / CGFloat(pitchesCount)
  let end_x = CGFloat(event.end) / CGFloat(pitchesCount)
  let mid_x = 0.5 * (start_x + end_x)
  let noteWidth = width * (end_x - start_x)
  let xpos = width * mid_x - 0.5 * noteWidth
  let ypos = height * (1 - CGFloat(((event.avPitch + event.pitchShift)-smallest)/range)) - 0.5 * noteHeight
  return .init(x: xpos, y: ypos, width: noteWidth, height: noteHeight)
}

//struct NotesView_Previews: PreviewProvider {
//    static var previews: some View {
//        NotesView()
//    }
//}
