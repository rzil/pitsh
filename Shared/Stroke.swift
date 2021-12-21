//
//  Stroke.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 22/12/21.
//

import SwiftUI

struct Stroke: Identifiable {
  let id = UUID()
  let start: CGPoint
  var points: [CGPoint] = []

  var path: Path {
    Path { path in
      path.move(to: start)
      for pt in points {
        path.addLine(to: pt)
      }
    }
  }
}
