//
//  File.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 12/1/2022.
//

import CoreData
import Foundation

extension PitshDocument {
  func performAutocorrelation(shouldContinue: ShouldContinue, audioFileURL: URL, completionHandler: @escaping (Result<Bool,Error>) -> ()) throws {
    let (floatData, sampleRate) = try audioFileURL.readAudioFile()
    guard let pitchShifter = PitchShifter(sampleRate: Float(sampleRate)) else {
      completionHandler(.failure(PitshError("Pitch shifter is nil")))
      return
    }
    let finishedShifting = pitchShifter.computePitchTrack(shouldContinue: &shouldContinue.value, indata: floatData)
    guard finishedShifting else {
      completionHandler(.success(false))
      return
    }
    guard let frequencies = pitchShifter.pitchTrack, let powers = pitchShifter.powerTrack else {
      completionHandler(.failure(PitshError("No pitch or power")))
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
      completionHandler(.failure(PitshError("No managed object context")))
      return
    }

    moc.perform {[weak self] in
      guard let self = self else {
        completionHandler(.failure(PitshError("No self")))
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
        completionHandler(.failure(error))
        return
      }

      completionHandler(.success(true))
    }
  }
}
