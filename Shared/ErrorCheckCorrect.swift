//
//  ErrorCheckCorrect.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 16/5/2022.
//

import Foundation
import CoreGraphics

func ecc<T: FloatingPoint>(_ x: T) -> T {
  if x.isFinite, x > 0 {
    return x
  } else {
    return 1
  }
}

func ecc(_ r: CGRect) -> CGRect {
  let x = r.origin.x
  let y = r.origin.y
  let w = r.size.width
  let h = r.size.height
  if x.isFinite, y.isFinite, w.isFinite, w > 0, h.isFinite, h > 0 {
    return r
  } else {
    return .init(origin: .zero, size: .init(width: 1, height: 1))
  }
}
