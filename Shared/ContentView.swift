//
//  ContentView.swift
//  Shared
//
//  Created by Ruben Zilibowitz on 23/7/21.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    let context = Current.coreData.persistentContainer().viewContext
    let _ = try! Current.coreData.getDocument()
    let conductor = Current.conductor
    SongView()
      .environment(\.managedObjectContext, context)
      .frame(minWidth: 400, minHeight: 200)
      .onAppear {
        conductor.start()
      }
      .onDisappear {
        conductor.stop()
      }
  }
}

//struct ContentView_Previews: PreviewProvider {
//  static var previews: some View {
//    ContentView()
//  }
//}
