//
//  KeysView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 24/12/2021.
//

import SwiftUI

enum KeySignature: String, CaseIterable, Identifiable {
  case cMajor   = "C Major"
  case dbMajor  = "D♭ Major"
  case dMajor   = "D Major"
  case ebMajor  = "E♭ Major"
  case eMajor   = "E Major"
  case fMajor   = "F Major"
  case fsMajor  = "F♯ Major"
  case gMajor   = "G Major"
  case gsMajor  = "G♯ Major"
  case aMajor   = "A Major"
  case bbMajor  = "B♭ Major"
  case bMajor   = "B Major"

  case cminor   = "C minor"
  case dbminor  = "D♭ minor"
  case dminor   = "D minor"
  case ebminor  = "E♭ minor"
  case eminor   = "E minor"
  case fminor   = "F minor"
  case fsminor  = "F♯ minor"
  case gminor   = "G minor"
  case abminor  = "A♭ minor"
  case aminor   = "A minor"
  case bbminor  = "B♭ minor"
  case bminor   = "B minor"

  var id: String { self.rawValue }
}

struct KeysView: View {
  @Environment(\.dismiss) var dismiss
  
  @FetchRequest(
    entity: PitshDocument.entity(),
    sortDescriptors: []
  ) var documents: FetchedResults<PitshDocument>
  
  private var rankedKeys: [KeySignature] {
    guard let eventsSorted = documents.first?.eventsSorted else { return [] }
    let kd = KeyDetector()
    let keys = kd.process(notes: eventsSorted.map({(Int(round($0.avPitch + $0.pitchShift)), Double($0.end - $0.start) * Double($0.avPower))}))
    return keys
      .sorted(by: { $0.score > $1.score })
      .map({KeySignature.allCases[$0.root + ($0.major ? 0 : 12)]})
  }

  @State private var selectedKey = KeySignature.cMajor

  var body: some View {
    Picker("Key", selection: $selectedKey) {
      ForEach(rankedKeys) { key in
        Text(key.rawValue).tag(key)
      }
    }
    .pickerStyle(InlinePickerStyle())
    Text("Selected key: \(selectedKey.rawValue)")

    Button("Done") {
      dismiss()
    }
  }
}

//struct KeysView_Previews: PreviewProvider {
//    static var previews: some View {
//        KeysView()
//    }
//}
