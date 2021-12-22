//
//  PitshError.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 22/12/2021.
//

import Foundation

class PitshError: LocalizedError {
  private let message: String
  init(_ message: String) {
    self.message = message
  }
  var errorDescription: String? { return message }
}
