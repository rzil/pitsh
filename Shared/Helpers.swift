//
//  Helpers.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 19/12/21.
//

import Foundation

func const<T>(_ x: T) -> () -> T { { x } }
