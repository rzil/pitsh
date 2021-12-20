//
//  WaveView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 20/12/21.
//

import SwiftUI

struct WaveView: View {
  @FetchRequest(
    entity: PitshDocument.entity(),
    sortDescriptors: []
  ) var documents: FetchedResults<PitshDocument>

  var body: some View {
    GeometryReader { geometry in
      if let document = self.documents.first {
        let paths = strokes(width: geometry.size.width, height: geometry.size.height, document: document)
        ForEach(paths) { strokePath in
          Path { path in
            path.move(to: strokePath.start)
            for pt in strokePath.points {
              path.addLine(to: pt)
            }
          }
          .stroke()
        }
      }
    }
    .background(Color.purple)
  }
}

struct Stroke: Identifiable {
  let id = UUID()
  let start: CGPoint
  var points: [CGPoint] = []
}

private func strokes(width: CGFloat, height: CGFloat, document: PitshDocument) -> [Stroke] {
  guard let pitches = document.pitches else { return [] }
  let length = pitches.count
  var penDown:Bool = false
  var strokes: [Stroke] = []
  var stroke: Stroke? = nil
  for x in 0 ..< Int(width) {
    let pos = Float(x) / Float(width) * Float(length)
    let int_pos = Int(pos)
    if (int_pos+1 < length) {
      let frac_pos = pos - Float(int_pos)
      let y1 = pitches[int_pos]
      let y2 = pitches[int_pos+1]
      let y = Float(y1) * (1 - frac_pos) + Float(y2) * frac_pos
      if (!penDown && (y1 > 0 && y2 > 0)) {
        penDown = true
        stroke = Stroke(start: CGPoint(x: CGFloat(x), y: document.convert(pitch: y, containerHeight: height)))
      }
      else if (penDown && (y1 < 0 || y2 < 0)) {
        penDown = false
        strokes.append(stroke!)
        stroke = nil
      }
      else if (penDown) {
        stroke?.points.append(CGPoint(x: CGFloat(x), y: document.convert(pitch: y, containerHeight: height)))
      }
    }
  }
  if (penDown) {
    strokes.append(stroke!)
    stroke = nil
  }
  return strokes
}

//struct WaveView_Previews: PreviewProvider {
//    static var previews: some View {
//        WaveView()
//    }
//}
