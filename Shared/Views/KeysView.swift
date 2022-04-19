//
//  KeysView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 24/12/2021.
//

import SwiftUI

private enum KeySignature: Int, CaseIterable, Identifiable {
  case cMajor
  case dbMajor
  case dMajor
  case ebMajor
  case eMajor
  case fMajor
  case fsMajor
  case gMajor
  case gsMajor
  case aMajor
  case bbMajor
  case bMajor

  case cminor
  case dbminor
  case dminor
  case ebminor
  case eminor
  case fminor
  case fsminor
  case gminor
  case abminor
  case aminor
  case bbminor
  case bminor

  var name: String {
    switch self {
    case .cMajor:   return "C Major"
    case .dbMajor:  return "D♭ Major"
    case .dMajor:   return "D Major"
    case .ebMajor:  return "E♭ Major"
    case .eMajor:   return "E Major"
    case .fMajor:   return "F Major"
    case .fsMajor:  return "F♯ Major"
    case .gMajor:   return "G Major"
    case .gsMajor:  return "G♯ Major"
    case .aMajor:   return "A Major"
    case .bbMajor:  return "B♭ Major"
    case .bMajor:   return "B Major"
      
    case .cminor:   return "C minor"
    case .dbminor:  return "D♭ minor"
    case .dminor:   return "D minor"
    case .ebminor:  return "E♭ minor"
    case .eminor:   return "E minor"
    case .fminor:   return "F minor"
    case .fsminor:  return "F♯ minor"
    case .gminor:   return "G minor"
    case .abminor:  return "A♭ minor"
    case .aminor:   return "A minor"
    case .bbminor:  return "B♭ minor"
    case .bminor:   return "B minor"
    }
  }

  var id: Int { self.rawValue }
}

struct KeysView: View {
  init(_ document: PitshDocument) {
    self.document = document
    let keyPair = document.keyPair
    let selectedKey = KeySignature.allCases[keyPair.root + (keyPair.major ? 0 : 12)]
    self._selectedKey = .init(initialValue: selectedKey)
  }
  
  @Environment(\.dismiss) var dismiss
  private let document: PitshDocument
  
  private var rankedKeys: [KeySignature] {
    guard let eventsSorted = document.eventsSorted else { return [] }
    let kd = KeyDetector()
    let keys = kd.process(notes: eventsSorted.map({(Int(round($0.avPitch + $0.pitchShift)), Double($0.end - $0.start) * Double($0.avPower))}))
    return keys
      .sorted(by: { $0.score > $1.score })
      .map({KeySignature.allCases[$0.root + ($0.major ? 0 : 12)]})
  }
  
  @State private var selectedKey: KeySignature
  
  var body: some View {
    Picker("Key", selection: $selectedKey) {
      ForEach(rankedKeys) { key in
        Text(key.name).tag(key)
      }
    }
    .pickerStyle(InlinePickerStyle())
    Text("Selected key: \(selectedKey.name)")
    
    HStack {
      Spacer()
      Button(action: { dismiss() }) {
        Text("Cancel")
          .frame(maxWidth: .infinity, maxHeight: 44)
      }
      .buttonStyle(.bordered)
      Spacer()
      Button(action: {
        document.key = Int16(selectedKey.rawValue)
        dismiss()
      }) {
        Text("Done")
          .frame(maxWidth: .infinity, maxHeight: 44)
      }
      .buttonStyle(.bordered)
      Spacer()
    }
  }
}

//struct KeysView_Previews: PreviewProvider {
//    static var previews: some View {
//        KeysView()
//    }
//}
