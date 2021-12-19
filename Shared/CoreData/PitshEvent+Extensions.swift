//
//  PitshEvent+Extensions.swift
//  Nika
//
//  Created by Ruben Zilibowitz on 10/9/18.
//  Copyright © 2018 Ruben Zilibowitz. All rights reserved.
//

import Foundation
import CoreData

extension PitshEvent {
  func updateFrom(noteEvent: NoteDetect.NoteEvent) {
    self.avPitch = noteEvent.avPitch
    self.avPower = noteEvent.avPower
    self.maxPitch = noteEvent.maxPitch
    self.minPitch = noteEvent.minPitch
    self.start = Int32(noteEvent.start)
    self.end = Int32(noteEvent.end)
    self.pitchShift = noteEvent.pitchShift
    self.pitchStart = Int32(noteEvent.pitchStart)
    self.pitchEnd = Int32(noteEvent.pitchEnd)
  }
  
  func copyAttributes(from event: PitshEvent) {
    self.avPitch = event.avPitch
    self.avPower = event.avPower
    self.maxPitch = event.maxPitch
    self.minPitch = event.minPitch
    self.start = event.start
    self.end = event.end
    self.pitchShift = event.pitchShift
    self.pitchStart = event.pitchStart
    self.pitchEnd = event.pitchEnd
  }
  
  func snapToKey() {
    guard let (root,isMajor) = relatedDocument?.keyPair else { return }
    let pitch = avPitch + pitchShift
    let scale = (isMajor ? [0,2,4,5,7,9,11] : [0,2,3,5,7,8,9,10,11]).map({($0 + root) % 12})
    func f(x:Float) -> Float {
      return abs(fmodf_neg(abs(x), 12))
    }
    let best = scale.min(by: {(a,b) in f(x: pitch - Float(a)) <= f(x: pitch - Float(b))})!
    let offset = fmodf_neg(pitch - Float(best), 12)
    
    // apply offset
    self.pitchShift -= offset
  }
  
  /*
   func split(at location: Float) {
   guard let moc = self.managedObjectContext else { return }
   self.relatedChord?.splitIntoEvents(completion: {error in
   guard error == nil else { print(error!.localizedDescription); return }
   moc.perform {[unowned self] in
   do {
   guard let eventLeft = NSEntityDescription.insertNewObject(forEntityName: "PitshEvent", into: moc) as? PitshEvent else { return }
   eventLeft.copyAttributes(from: self)
   eventLeft.relatedDocument = self.relatedDocument
   
   if location <= Float(self.end) {
   eventLeft.end = Int32(floor(location))
   }
   
   guard let eventRight = NSEntityDescription.insertNewObject(forEntityName: "PitshEvent", into: moc) as? PitshEvent else { return }
   eventRight.copyAttributes(from: self)
   eventRight.relatedDocument = self.relatedDocument
   
   if Float(eventRight.start) < location {
   eventRight.start = Int32(ceil(location))
   }
   
   if let relatedChord = self.relatedChord {
   moc.delete(relatedChord)
   }
   moc.delete(self)
   
   if moc.hasChanges {
   try moc.save()
   }
   }
   catch {
   print(error)
   }
   }
   })
   }
   */
  
  func setSelection(_ selection: Bool = true) {
    guard let moc = managedObjectContext else { return }
    moc.perform {[unowned self] in
      //            moc.undoManager?.disableUndoRegistration()
      self.isSelected = selection
      if moc.hasChanges {
        do { try moc.save() }
        catch { NSLog(error.localizedDescription) }
      }
      //            moc.undoManager?.enableUndoRegistration()
    }
  }
  
  var effectivePitch: Float {
    return avPitch + pitchShift
  }
}
