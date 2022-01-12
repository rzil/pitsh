//
//  KeysView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 24/12/2021.
//

import SwiftUI

struct KeysView: View {
  @Environment(\.dismiss) var dismiss

  var body: some View {
    Text("Hello, World!")
    Button("Dismiss Me") {
        dismiss()
    }
  }
}

//struct KeysView_Previews: PreviewProvider {
//    static var previews: some View {
//        KeysView()
//    }
//}
