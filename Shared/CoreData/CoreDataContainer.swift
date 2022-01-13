//
//  CoreDataContainer.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 19/12/21.
//

import CoreData
import Foundation

final class CoreDataContainer: NSPersistentContainer, ObservableObject {
  @Published private(set) var error: Error?
  @Published private(set) var didLoad: Bool = false

  init(name: String, bundle: Bundle = .main, inMemory: Bool = false) {
    guard let mom = NSManagedObjectModel.mergedModel(from: [bundle]) else {
      fatalError("Failed to create managed object model")
    }
    super.init(name: name, managedObjectModel: mom)
    configureDefaults()
    loadStores()
    viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    viewContext.undoManager = UndoManager()
  }

  private func configureDefaults(_ inMemory: Bool = false) {
    if let storeDescription = persistentStoreDescriptions.first {
      storeDescription.shouldAddStoreAsynchronously = false
      if inMemory {
        storeDescription.type = NSInMemoryStoreType
      }
    }
  }

  private func loadStores() {
    loadPersistentStores { [weak self] _, error in
      guard let self = self else { return }
      self.error = error
      self.didLoad = true
      print("*** loaded persistent stores")
    }
  }

  func saveContext() {
    do {
      if viewContext.hasChanges {
        try viewContext.save()
      }
    } catch {
      print(error)
    }
  }
}
