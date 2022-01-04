//
//  KeysView.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 24/12/2021.
//

import SwiftUI

struct KeysView: View {
  @Environment(\.presentationMode) var presentationMode

  var body: some View {
    Text("Hello, World!")
    Button("Dismiss Me") {
        presentationMode.wrappedValue.dismiss()
    }
  }
}

//struct KeysView_Previews: PreviewProvider {
//    static var previews: some View {
//        KeysView()
//    }
//}
