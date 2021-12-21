//
//  NoteView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 21/12/21.
//

import SwiftUI

struct NoteView: View {
  @State var event: PitshEvent?

  var body: some View {
    GeometryReader { geometry in
      if let event = self.event {
        let bounds = geometry.frame(in: .local)
        Rectangle()
          .stroke(Color(white: 0.5, opacity: 1))
          .frame(width: bounds.width, height: bounds.height)
        let middleHue = CGFloat(fmodf_pos(1.0/6.0 + event.pitchShift*0.2, 1.0))
        let middleColor = Color(hue: middleHue, saturation: 0.25, brightness: 1, opacity: 1)
        let outerColor = Color(hue: middleHue, saturation: 1, brightness: 1, opacity: 1)
        let stroke = stroke(frame: bounds, event: event)
        stroke?.path
          .fill(.linearGradient(
            Gradient(colors: [outerColor, middleColor, outerColor]),
            startPoint: UnitPoint(x: 0.5, y: 0),
            endPoint: UnitPoint(x: 0.5, y: 1)
          ))
      }
    }
  }
}

private func stroke(frame: CGRect, event: PitshEvent) -> Stroke? {
  guard let powers = event.relatedDocument?.normalisedPowers else { return nil }
  let noteStart = event.start
  let noteEnd = event.end
  let length = noteEnd - noteStart
  let width = frame.width
  let midY = frame.midY
  let halfHeight = frame.height * 0.5

  var stroke = Stroke(start: CGPoint(x: 0, y: midY))
  for pos in noteStart ..< noteEnd {
    let x = CGFloat(pos - noteStart) * width / CGFloat(length)
    let env = powers[Int(pos)]
    stroke.points.append(CGPoint(x: x, y: midY + halfHeight*CGFloat(env)))
  }
  stroke.points.append(CGPoint(x: frame.maxX, y: midY))
  for pos in stride(from: noteEnd-1, to: noteStart-1, by: -1) {
    let x = CGFloat(pos-noteStart) * width / CGFloat(length)
    let env = powers[Int(pos)]
    stroke.points.append(CGPoint(x: x, y: midY - halfHeight*CGFloat(env)))
  }
  stroke.points.append(CGPoint(x: 0, y: midY))
  return stroke
}

//struct NoteView_Previews: PreviewProvider {
//    static var previews: some View {
//        NoteView()
//    }
//}
