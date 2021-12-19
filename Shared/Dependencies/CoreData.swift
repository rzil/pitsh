//
//  CoreData.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 19/12/21.
//

import CoreData
import Foundation

private let coreDataContainer = CoreDataContainer(name: "Pitsh")

struct CoreData {
  var persistentContainer: () -> CoreDataContainer = const(coreDataContainer)

  func getDocument() throws -> PitshDocument {
    var doc: PitshDocument? = nil
    let moc = persistentContainer().viewContext
    try moc.performAndWait {
      let fetchRequest: NSFetchRequest<PitshDocument> = PitshDocument.fetchRequest()
      let documents = try fetchRequest.execute()
      guard documents.count < 2 else {
        throw NSError(domain: "Too many documents", code: 1, userInfo: nil)
      }
      if let result = documents.first {
        doc = result
      }
      else {
        guard let aDocument = NSEntityDescription.insertNewObject(forEntityName: "PitshDocument", into: moc) as? PitshDocument else {
          throw NSError(domain: "Failed to create document", code: 1, userInfo: nil)
        }
        aDocument.title = "Pitsh Song"
        aDocument.setupAudioFile()
        if moc.hasChanges {
          try moc.save()
        }
        doc = aDocument
      }
    }
    return doc!
  }
}
