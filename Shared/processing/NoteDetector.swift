//
//  NoteDetector.swift
//  Pitsh
//
//  Created by Ruben Zilibowitz on 28/8/18.
//  Copyright © 2018 Ruben Zilibowitz. All rights reserved.
//

import Foundation

class NoteDetect {
  class NoteEvent {
    var start, end, pitchStart, pitchEnd: Int
    var avPitch, avPower, minPitch, maxPitch: Float
    var pitchShift: Float
    
    init(start: Int, end: Int, pitchStart: Int, pitchEnd: Int, avPitch: Float, avPower: Float, minPitch: Float, maxPitch: Float, pitchShift: Float) {
      self.start = start
      self.end = end
      self.pitchStart = pitchStart
      self.pitchEnd = pitchEnd
      self.avPitch = avPitch
      self.avPower = avPower
      self.minPitch = minPitch
      self.maxPitch = maxPitch
      self.pitchShift = pitchShift
    }
  }
  
  var minNoteFrames: Int = 0
  var pitchRange: Float = 0.5
  
  func process(pitchTrack: [Float], envelope: [Float], minNoteFrames: Int) -> [NoteEvent] {
    self.minNoteFrames = minNoteFrames
    let events = computeNoteEventsFromPitches(pitchTrack: pitchTrack, envelope: envelope)
    return events
  }
  
  private func computeNoteEventsFromPitches(pitchTrack: [Float], envelope: [Float]) -> [NoteEvent] {
    let events = subdivide(pitchTrack: pitchTrack)
    for i in 0 ..< events.count {
      var avPitch:Float = 0, minPitch:Float = 1e6, maxPitch:Float = -1e6, totalPower:Float = 0
      for pos in events[i].pitchStart ..< events[i].pitchEnd {
        let pitch = pitchTrack[pos]
        minPitch = min(pitch, minPitch)
        maxPitch = max(pitch, maxPitch)
        avPitch += pitch * envelope[pos]
        totalPower += envelope[pos]
      }
      avPitch /= totalPower
      events[i].avPitch = avPitch
      events[i].avPower = totalPower / Float(events[i].pitchEnd - events[i].pitchStart)
      events[i].minPitch = minPitch
      events[i].maxPitch = maxPitch
    }
    
    // compute tuning correction - as described section 2 of
    // this paper http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.12.3279
    var delta: Float = 0
    for e in events {
      delta += fmodf(e.avPitch + 0.5, 1.0) - 0.5
    }
    delta /= Float(events.count)
    let pitchCorrection = fmodf(delta + 0.5, 1.0) - 0.5
    for i in 0 ..< events.count {
      events[i].avPitch -= pitchCorrection
    }
    
    return events
  }
  
  private func subdivide(pitchTrack: [Float]) -> [NoteEvent] {
    var events: [NoteEvent] = []
    var i: Int = 0
    while i < pitchTrack.count {
      if pitchTrack[i] > 0 {
        for j in i ... pitchTrack.count {
          if j == pitchTrack.count || pitchTrack[min(j,pitchTrack.count-1)] < 0 {
            var newEvents = recurseEventsFromPitches(pitchTrack: pitchTrack, start: i, length: j - i)
            extendEventsFromPitches(pitchTrack: pitchTrack, start: i, end: j, events: &newEvents)
            events.append(contentsOf: newEvents)
            i = j
            break
          }
        }
      }
      i += 1
    }
    
    return events
  }
  
  private func extendEventsFromPitches(pitchTrack: [Float], start: Int, end: Int, events: inout [NoteEvent]) {
    if events.count > 0 {
      events.sort(by: {$0.pitchStart < $1.pitchStart})
      events[0].start = start
      events[events.count - 1].end = end
      
      var pitchesDeriv = pitchTrack
      derivative3Point(data: &pitchesDeriv, stepSize: 1)
      for j in 1 ..< events.count {
        let ievent = events[j-1]
        let jevent = events[j]
        let iend = ievent.pitchEnd
        let jstart = jevent.pitchStart
        var maxDeriv: Float = 0
        var boundary = iend
        for pos in iend ..< jstart {
          let d = abs(pitchesDeriv[pos])
          if d > maxDeriv {
            maxDeriv = d
            boundary = pos
          }
        }
        events[j-1].end = boundary
        events[j].start = boundary
      }
      
    }
  }
  
  private func derivative3Point(data: inout [Float], stepSize: Float) {
    let length = data.count
    let factor = 1 / (2*stepSize)
    
    let begin1 = (-data[0] + 4*data[1] - 3*data[2]) * factor;
    let end1 = (3*data[length-3] - 4*data[length-2] + data[length-1]) * factor;
    
    for i in 2 ..< length {
      data[i-2] = (data[i] - data[i-2]) * factor;
    }
    
    data.insert(begin1, at: 0)
    data.append(end1)
  }
  
  private func recurseEventsFromPitches(pitchTrack: [Float], start: Int, length: Int) -> [NoteEvent] {
    var events: [NoteEvent] = []
    if (length >= minNoteFrames) {
      if let event = bestEventFromPitches(pitchTrack: pitchTrack, start: start, length: length) {
        assert(event.pitchStart >= start)
        assert(event.pitchEnd <= start+length)
        events.append(event)
        
        // split search space and recursively search each part
        events.append(contentsOf: recurseEventsFromPitches(pitchTrack: pitchTrack, start: start, length: event.pitchStart - start))
        events.append(contentsOf: recurseEventsFromPitches(pitchTrack: pitchTrack, start: event.pitchEnd, length: start + length - event.pitchEnd))
      }
    }
    
    return events
  }
  
  private func bestEventFromPitches(pitchTrack: [Float], start: Int, length: Int) -> NoteEvent? {
    // find the best note
    var bestNotelen: Int = 0
    var bestNotepos: Int = 0
    var pos: Int = 0
    while pos + bestNotelen < length {
      var notelen = maxNoteLengthAt(pos: pos+start, pitchTrack: pitchTrack)
      notelen = min(notelen, length-pos)
      if (notelen > bestNotelen) {
        bestNotelen = notelen
        bestNotepos = pos+start
      }
      pos += 1
    }
    
    // return result
    if (bestNotelen > minNoteFrames) {
      return NoteEvent(start: 0, end: 0, pitchStart: bestNotepos, pitchEnd: bestNotepos + bestNotelen, avPitch: 0, avPower: 0, minPitch: 0, maxPitch: 0, pitchShift: 0)
    }
    
    return nil
  }
  
  private func maxNoteLengthAt(pos: Int, pitchTrack: [Float]) -> Int {
    let startPitch = pitchTrack[pos]
    for endPos in pos ..< pitchTrack.count {
      let pitch = pitchTrack[endPos]
      if (abs(pitch-startPitch) > pitchRange) {
        return (endPos - pos - 1)
      }
    }
    return (pitchTrack.count - pos - 1)
  }
}
