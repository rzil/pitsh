//
//  Utilities.swift
//  Pitsh
//
//  Created by Ruben Zilibowitz on 22/9/18.
//  Copyright © 2018 Ruben Zilibowitz. All rights reserved.
//

import Foundation

func imod(_ x: Int, _ y: Int) -> Int {
  return ((x % y) + y) % y
}

func imod_neg(_ x: Int, _ y: Int) -> Int {
  let z = ((x % y) + y) % y
  if 2*z >= y {
    return z - y
  }
  return z
}

func fmodf_pos(_ x: Float, _ y: Float) -> Float {
  let z = fmodf(fmodf(x, y) + y, y)
  return z
}

func fmodf_neg(_ x: Float, _ y: Float) -> Float {
  let z = fmodf_pos(x, y)
  if 2*z >= y {
    return z - y
  }
  return z
}

func sqr<T:Numeric>(_ x: T) -> T {
  return x * x
}
