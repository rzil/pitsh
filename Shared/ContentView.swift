//
//  ContentView.swift
//  Shared
//
//  Created by Ruben Zilibowitz on 23/7/21.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
//    let context = Current.coreData.persistentContainer().viewContext
//    SongView().environment(\.managedObjectContext, context)
    RecorderView()
  }
}

//struct ContentView_Previews: PreviewProvider {
//  static var previews: some View {
//    ContentView()
//  }
//}
