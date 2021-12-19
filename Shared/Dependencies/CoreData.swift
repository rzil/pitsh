//
//  CoreData.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 19/12/21.
//

import Foundation

private let container = CoreDataContainer(name: "Pitsh")

struct CoreData {
  var persistentContainer: () -> CoreDataContainer = const(container)
}
