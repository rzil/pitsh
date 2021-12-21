//
//  WaveView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 20/12/21.
//

import SwiftUI

private let gridColor1 = Color(red: 0.8, green: 0.8, blue: 1, opacity: 1)
private let gridColor2 = Color(red: 0.9, green: 0.9, blue: 1, opacity: 1)

struct WaveView: View {
  @FetchRequest(
    entity: PitshDocument.entity(),
    sortDescriptors: []
  ) var documents: FetchedResults<PitshDocument>

  var body: some View {
    GeometryReader { geometry in
      if let document = self.documents.first {
        // draw grid
        let rects = grid(width: geometry.size.width, height: geometry.size.height, document: document)
        ForEach(rects) { r in
          Rectangle()
              .fill(gridColor2)
              .offset(x: r.rect.minX, y: r.rect.minY)
              .frame(width: r.rect.width, height: r.rect.height)
        }

        // draw audio
        let paths = strokes(width: geometry.size.width, height: geometry.size.height, document: document)
        ForEach(paths) { strokePath in
          strokePath.path
            .stroke(Color.red, lineWidth: 1.5)
        }
      }
    }
    .background(gridColor1)
  }
}

private struct GridRectangle: Identifiable {
  let id = UUID()
  let rect: CGRect
}

private func grid(width: CGFloat, height: CGFloat, document: PitshDocument) -> [GridRectangle] {
  let (smallest, biggest) = document.visiblePitchRange
  let minPitch = Int(smallest)
  let maxPitch = Int(biggest + 3)
  var rects: [CGRect] = []
  for idx in stride(from: minPitch, to: maxPitch, by: 2) {
      let y = document.convert(pitch: Float(idx) + 0.5, containerHeight: height)
      rects.append(CGRect(x: 0, y: y, width: width, height: document.gridSpacing(containerHeight: height)))
  }
  return rects.map(GridRectangle.init(rect:))
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
