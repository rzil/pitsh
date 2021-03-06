//
//  NoteNamesView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 21/12/21.
//

import SwiftUI

struct NoteNamesView: View {
  let documents: FetchedResults<PitshDocument>
  private var document: PitshDocument {
    documents.first!
  }

  var body: some View {
    GeometryReader { geometry in
      ForEach(noteNames(height: geometry.size.height, document: document)) { x in
        Text(x.name)
          .foregroundColor(.black)
          .font(.caption)
          .offset(x: 8, y: x.minY)
          .frame(height: x.height, alignment: .center)
      }
    }
  }
}

private struct NoteName: Identifiable {
  let id = UUID()
  let name: String
  let height: CGFloat
  let minY: CGFloat
}

private func noteNames(height: CGFloat, document: PitshDocument) -> [NoteName] {
  let (smallest, biggest) = document.visiblePitchRange
  let range = biggest - smallest
  guard range > 0 else { return [] }
  let minPitch = Int(smallest)
  let maxPitch = Int(biggest + 3)
  let noteHeight = height / CGFloat(range)
  let pitches = stride(from: minPitch, to: maxPitch, by: noteHeight > 16 ? 1 : 2)
  return pitches.map {
    NoteName(
      name: noteName(from: $0),
      height: noteHeight,
      minY:  height * (1 - CGFloat((Float($0) - smallest) / range)) - 0.5 * noteHeight
    )
  }
}

private func noteName(from int: Int) -> String {
    let octave = (int / 12) + 2
    return noteToStr(x: imod_neg(int * 7, 12)) + String(octave)
}

private func noteToStr(x: Int) -> String {
    let name = ["C","D","E","F","G","A","B"]
    let acc = noteGetAcc(x: x)
    return name[imod(x * 4, 7)] + (acc >= 0 ? String(repeating: "♯", count: acc) : String(repeating: "♭", count: -acc))
}

private func noteGetAcc(x: Int) -> Int {
    return Int(floor(Double((x + 1)) / 7))
}
