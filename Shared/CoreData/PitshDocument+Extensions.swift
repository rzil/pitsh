//
//  PitshDocument+Extensions.swift
//  Nika
//
//  Created by Ruben Zilibowitz on 12/9/18.
//  Copyright © 2018 Ruben Zilibowitz. All rights reserved.
//

import Foundation
import CoreData
import CoreGraphics

private func getDocumentsDirectory() -> URL {
  let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
  let documentsDirectory = paths[0]
  return documentsDirectory
}

extension PitshDocument {
  
  enum Tool: Int16 {
    case grab
    case glue
    case cut
    case draw
    
    var name: String {
      switch self {
      case .grab: return "Grab"
      case .glue: return "Glue"
      case .cut: return "Cut"
      case .draw: return "Draw"
      }
    }
  }

  var audioFileURL: URL? {
    guard let audioFile = self.audioFile else { return nil }
    return getDocumentsDirectory().appendingPathComponent(audioFile).appendingPathExtension("aiff")
  }

  var shiftedAudioFileURL: URL? {
    guard let shiftedAudioFile = self.shiftedAudioFile else { return nil }
    return getDocumentsDirectory().appendingPathComponent(shiftedAudioFile).appendingPathExtension("aiff")
  }

  func saveSelectedTool(_ tool: Tool) {
    guard let moc = managedObjectContext else { return }
    moc.perform {[unowned self] in
      //            moc.undoManager?.disableUndoRegistration()
      self.tool = tool.rawValue
      if moc.hasChanges {
        do { try moc.save() }
        catch { NSLog(error.localizedDescription) }
      }
      //            moc.undoManager?.enableUndoRegistration()
    }
  }
  
  var selectedTool: Tool {
    get {
      return Tool(rawValue: self.tool) ?? .grab
    }
    set {
      self.tool = newValue.rawValue
    }
  }
  
  var keyString: String {
    let root = self.key % 12
    let isMajor = self.key < 12
    return keyStringFrom(root: Int(root), major: isMajor)
  }
  
  func keyStringFrom(root: Int, major: Bool) -> String {
    return ["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"][root] + (major ? " Major" : " minor")
  }
  
  var keyPair: (root: Int, major: Bool) {
    get {
      let root = self.key % 12
      let isMajor = self.key < 12
      return (root: Int(root), major: isMajor)
    }
    set {
      self.key = Int16(newValue.root + (newValue.major ? 0 : 12))
    }
  }
  
  func setupAudioFiles() {
    self.audioFile = UUID().uuidString
    self.shiftedAudioFile = UUID().uuidString
  }
  
  func deselectAllEvents() {
    guard let moc = managedObjectContext else { return }
    moc.perform {[unowned self] in
      //            moc.undoManager?.disableUndoRegistration()
      (self.relatedEvents as? Set<PitshEvent>)?.forEach({$0.isSelected = false})
      if moc.hasChanges {
        do { try moc.save() }
        catch { NSLog(error.localizedDescription) }
      }
      //            moc.undoManager?.enableUndoRegistration()
    }
  }
  
  var selectedEvents: Set<PitshEvent> {
    let selectedEvents = (self.relatedEvents as? Set<PitshEvent>)?.filter({$0.isSelected})
    return selectedEvents ?? Set()
  }
  
  func deleteSelectedEvents() {
    guard let moc = self.managedObjectContext else { return }
    let selectedEvents = self.selectedEvents
    moc.perform {
      do {
        for event in selectedEvents {
          moc.delete(event)
        }
        
        if moc.hasChanges {
          try moc.save()
        }
      }
      catch {
        print(error)
      }
    }
  }
  
  func glueSelectedEvents() {
    let selectedEvents = self.selectedEvents
    guard selectedEvents.count > 1 else { return }
    let selectionEnd = selectedEvents.reduce(0, {result, event in max(result, event.end)})
    let songEnd = Int32(self.pitches?.count ?? 0)
    let selectionStart = selectedEvents.reduce(songEnd, {result, event in min(result, event.start)})
    
    guard let eventsToGlue = (relatedEvents as? Set<PitshEvent>)?.filter({let mid = ($0.start + $0.end)/2; return selectionStart <= mid && mid < selectionEnd}) else { return }
    
    let avPitch = eventsToGlue.reduce(0, {result, ev in result + ev.avPitch}) / Float(eventsToGlue.count)
    let avPower = eventsToGlue.reduce(0, {result, ev in result + ev.avPower}) / Float(eventsToGlue.count)
    let minPitch = eventsToGlue.reduce(0, {result, ev in min(result, ev.minPitch)})
    let maxPitch = eventsToGlue.reduce(0, {result, ev in max(result, ev.maxPitch)})
    let pitchShift = eventsToGlue.reduce(0, {result, ev in result + ev.pitchShift}) / Float(eventsToGlue.count)
    let start = eventsToGlue.reduce(songEnd, {result, ev in min(result, ev.start)})
    let end = eventsToGlue.reduce(0, {result, ev in max(result, ev.end)})
    let pitchStart = eventsToGlue.reduce(songEnd, {result, ev in min(result, ev.pitchStart)})
    let pitchEnd = eventsToGlue.reduce(0, {result, ev in max(result, ev.pitchEnd)})
    
    guard let moc = self.managedObjectContext else { return }
    moc.perform {[unowned self] in
      eventsToGlue.forEach({moc.delete($0)})
      guard let newEvent = NSEntityDescription.insertNewObject(forEntityName: "PitshEvent", into: moc) as? PitshEvent else { return }
      newEvent.avPitch = avPitch
      newEvent.avPower = avPower
      newEvent.minPitch = minPitch
      newEvent.maxPitch = maxPitch
      newEvent.pitchShift = pitchShift
      newEvent.start = start
      newEvent.end = end
      newEvent.pitchStart = pitchStart
      newEvent.pitchEnd = pitchEnd
      self.addToRelatedEvents(newEvent)
      
      do {
        if moc.hasChanges {
          try moc.save()
        }
      }
      catch {
        print(error)
      }
    }
  }
  
  func createTruncatedEvents(starting: Int32, ending: Int32, pitch: Float) {
    // compute overlapping events with given interval
    guard let overlappingEvents = (relatedEvents as? Set<PitshEvent>)?.filter({max(starting, $0.start) < min(ending,$0.end)}) else { return }
    
    let starts = overlappingEvents.map({$0.start}).sorted()
    let ends = overlappingEvents.map({$0.end}).sorted()
    
    var location: Int32 = starting
    var outsideEvent: Bool = overlappingEvents.filter({$0.start <= starting && starting < $0.end}).count == 0
    
    var intervals: [(Int32,Int32)] = []
    
    while location < ending {
      if outsideEvent {
        let startLocation = location
        if let s = starts.filter({location <= $0}).first {
          location = s
          outsideEvent = false
        }
        else {
          location = ending
        }
        
        // save (startLocation, location)
        intervals.append((startLocation, location))
      }
      else {
        if let e = ends.filter({location < $0}).first, e <= ending {
          location = e
          outsideEvent = true
        }
        else {
          location = ending
        }
      }
    }
    
    // create the new events
    guard let pitches = self.pitches, let powers = self.powers else { return }
    guard let moc = self.managedObjectContext else { return }
    moc.perform {[unowned self] in
      do {
        for (truncatedStart,truncatedEnd) in intervals {
          guard truncatedEnd - truncatedStart > 4 else { continue }
          var avPitch:Float = 0, minPitch:Float = 1e6, maxPitch:Float = -1e6, totalPower:Float = 0
          for pos in Int(truncatedStart) ..< Int(truncatedEnd) {
            let pitch = pitches[pos]
            minPitch = min(pitch, minPitch)
            maxPitch = max(pitch, maxPitch)
            avPitch += pitch * powers[pos]
            totalPower += powers[pos]
          }
          avPitch /= totalPower
          let avPower = totalPower / Float(truncatedEnd - truncatedStart)
          
          guard let newEvent = NSEntityDescription.insertNewObject(forEntityName: "PitshEvent", into: moc) as? PitshEvent else { return }
          newEvent.avPitch = pitch //avPitch
          newEvent.avPower = avPower
          newEvent.minPitch = minPitch
          newEvent.maxPitch = maxPitch
          newEvent.pitchShift = 0 //pitch - avPitch
          newEvent.start = truncatedStart
          newEvent.end = truncatedEnd
          newEvent.pitchStart = truncatedStart
          newEvent.pitchEnd = truncatedEnd
          self.addToRelatedEvents(newEvent)
        }
        if moc.hasChanges {
          try moc.save()
        }
      }
      catch {
        print(error)
      }
    }
  }
  
  var visiblePitchRange: (Float,Float) {
    return (minimumVisiblePitch, maximumVisiblePitch)
  }
  
  func findNextEvent(after location: Float) -> PitshEvent? {
    guard let events = relatedEvents as? Set<PitshEvent> else { return nil }
    return events.filter({location < Float($0.start)}).min(by: {(a,b) in return a.start < b.start})
  }
  
  func findEvents(at location: Float) -> [PitshEvent] {
    return (relatedEvents as? Set<PitshEvent>)?.filter({Float($0.start) <= location && location < Float($0.end)}) ?? []
  }
  
  var eventsSorted: [PitshEvent]? {
    (relatedEvents as? Set<PitshEvent>)?.sorted(by: { $0.start < $1.start })
  }
  
  func convert(horizontal: CGFloat, containerWidth: CGFloat) -> CGFloat {
    guard let length = pitches?.count else { return 0 }
    return horizontal * containerWidth / CGFloat(length)
  }
  
  func convert(pitch: Float, containerHeight: CGFloat) -> CGFloat {
    let (smallest, biggest) = visiblePitchRange
    let range = biggest - smallest
    return containerHeight - CGFloat((pitch-smallest)/range)*containerHeight
  }
  
  func gridSpacing(containerHeight: CGFloat) -> CGFloat {
    let (smallest, biggest) = visiblePitchRange
    let range = biggest - smallest
    return containerHeight/CGFloat(range)
  }
  
  func convertVerticalLocationToPitch(from vertical: CGFloat, containerHeight: CGFloat) -> Float {
    let (smallest, biggest) = visiblePitchRange
    let range = biggest - smallest
    return Float((containerHeight - vertical)/containerHeight)*range + smallest
  }
  
  func convertVerticalShiftToPitch(from vertical: CGFloat, containerHeight: CGFloat) -> Float {
    let (smallest, biggest) = visiblePitchRange
    let range = biggest - smallest
    return -Float(vertical/containerHeight)*Float(range)
  }
  
  func convertHorizontalLocationToIndex(from horizontal: CGFloat, containerWidth: CGFloat) -> Float {
    return Float((horizontal / containerWidth) * CGFloat(self.pitches?.count ?? 0))
  }
  
  func performAutocorrelation(completionHandler: @escaping (Error?) -> ()) throws {
    guard let (floatData, sampleRate) = try audioFileURL?.readAudioFile() else {
      completionHandler(PitshError("Audio file url is nil"))
      return
    }

    guard let pitchShifter = PitchShifter(sampleRate: Float(sampleRate)) else {
      completionHandler(PitshError("Pitch shifter is nil"))
      return
    }
    pitchShifter.computePitchTrack(indata: floatData)
    guard let frequencies = pitchShifter.pitchTrack, let powers = pitchShifter.powerTrack else {
      completionHandler(PitshError("No pitch or power"))
      return
    }
    let stepSize = pitchShifter.stepSize

    // convert frequency to well-tempered logarithmic scale
    let pitches:[Float] = frequencies.map {
      if $0 > 0 {
        return (12 * log2f($0 / 55)) - 3
      } else {
        return $0
      }
    }

    // normalise power
    let maxPower = max(abs(powers.max() ?? 0), abs(powers.min() ?? 0))
    let normalisedPowers = powers.map {$0 / maxPower}

    let nd = NoteDetect()
    let minNoteDuration:Double = 0.2
    let minNoteFrames = Int(sampleRate / Double(stepSize) * minNoteDuration)
    let events = nd.process(pitchTrack: pitches, envelope: powers, minNoteFrames: minNoteFrames)

    let kd = KeyDetector()
    let keys = kd.process(notes: events.map({(Int(round($0.avPitch + $0.pitchShift)), Double($0.end - $0.start) * Double($0.avPower))}))
    let bestKey = keys.first ?? (root: 0, major: true, score: 0)
    print(bestKey)

    guard let moc = self.managedObjectContext else {
      completionHandler(PitshError("No managed object context"))
      return
    }

    moc.perform {[weak self] in
      guard let self = self else {
        completionHandler(PitshError("No self"))
        return
      }
      self.audioSampleRate = sampleRate
      self.keyPair = (root: bestKey.root, major: bestKey.major)
      self.stepSize = Int16(stepSize)
      self.frequencies = frequencies
      self.pitches = pitches
      self.normalisedPowers = normalisedPowers
      self.powers = powers
      
      (self.relatedEvents as! Set<PitshEvent>).forEach({ moc.delete($0) })
      
      for e in events {
        guard let PitshEvent = NSEntityDescription.insertNewObject(
          forEntityName: "PitshEvent",
          into: moc
        ) as? PitshEvent else {
          print("failed to create PitshEvent object")
          continue
        }
        PitshEvent.updateFrom(noteEvent: e)
        self.addToRelatedEvents(PitshEvent)
      }

      let pitches = events.map({$0.avPitch})
      if let minPitch = pitches.min(), let maxPitch = pitches.max() {
        self.minimumVisiblePitch = minPitch - 12
        self.maximumVisiblePitch = maxPitch + 12
      }

      do {
        if moc.hasChanges {
          try moc.save()
        }
      }
      catch {
        completionHandler(error)
        return
      }

      completionHandler(nil)
    }
  }
}
