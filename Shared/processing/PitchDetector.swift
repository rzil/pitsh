//
//  PitchDetector.swift
//  Pitsh
//
//  Created by Ruben Zilibowitz on 27/8/18.
//  Copyright © 2018 Ruben Zilibowitz. All rights reserved.
//

import Foundation
import Accelerate

let pitchAudioStride: UInt32 = 512

class PitchDetector {
  var fftSetup: FFTSetup
  var A: COMPLEX_SPLIT!
  var log2n, n, nOver2: UInt32
  var audioStride: UInt32
  var dominantFrequencyStride: UInt32
  var dominantFrequencyLength: UInt32
  var pitchRange: Float
  var minNoteTime: Float
  var minPower: Float
  var Areal: [Float]
  var Aimag: [Float]
  var window: [Float]
  var work: [Float]
  var lowAFrequency: Float
  
  init?(audioStride: UInt32 = pitchAudioStride,
        dominantFrequencyStride: UInt32 = 1,
        dominantFrequencyLength: UInt32 = 1,
        logN: UInt32 = 12,
        pitchRange: Float = 0.5,
        minNoteTime: Float = 0.15,
        minPower: Float = 120.0) {
    
    self.log2n = logN
    self.n = 1 << log2n
    self.nOver2 = n / 2
    self.audioStride = audioStride
    self.dominantFrequencyStride = dominantFrequencyStride
    self.dominantFrequencyLength = dominantFrequencyLength
    self.pitchRange = pitchRange
    self.minNoteTime = minNoteTime
    self.minPower = minPower
    
    guard let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2n), FFTRadix(FFT_RADIX2)) else { return nil }
    self.fftSetup = fftSetup
    
    self.work = Array(repeating: 0, count: Int(nOver2))
    self.window = Array(repeating: 0, count: Int(n))
    vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
    
    self.lowAFrequency = 55
    
    self.Areal = Array(repeating: 0, count: Int(nOver2))
    self.Aimag = Array(repeating: 0, count: Int(nOver2))
    defer {
      Areal.withUnsafeMutableBufferPointer { ArealBP in
        Aimag.withUnsafeMutableBufferPointer { AimagBP in
          self.A = COMPLEX_SPLIT(realp: ArealBP.baseAddress!, imagp: AimagBP.baseAddress!)
        }
      }
    }
  }
  
  deinit {
    vDSP_destroy_fftsetup(fftSetup)
  }
  
  func process(sampleRate: Float,
               audio: [Float]) -> ([Float],[Float]) {
    
    var outPitches: [Float] = []
    var outPowers: [Float] = []
    
    var acFrames: [[Float]] = []
    var frame: Int = 0
    while frame + Int(n) <= Int(audio.count) {
      var audioFrame = Array(audio[frame ..< frame+Int(n)])
      autocorrelation(audio: &audioFrame)
      acFrames.append(audioFrame)
      if acFrames.count == dominantFrequencyLength {
        let (frequency,power) = dominantFrequency(cut: acFrames, sampleRate: sampleRate) ?? (-1,0)
        let pitch = power > minPower ? frequency : -1
        outPitches.append(pitch)
        outPowers.append(power)
        acFrames.removeFirst(Int(dominantFrequencyStride))
      }
      frame += Int(audioStride)
    }
    
    // convert frequency to well-tempered logarithmic scale
    for i in 0 ..< outPitches.count {
      if outPitches[i] > 0 {
        outPitches[i] = (12 * log2f(outPitches[i] / 55)) - 3
      }
    }
    
    // normalise power
    for i in 0 ..< outPowers.count {
      let maxPower = max(abs(outPowers.max() ?? 0), abs(outPowers.min() ?? 0))
      outPowers[i] /= maxPower
    }
    
    return (outPitches,outPowers)
  }
  
  private func autocorrelation(audio: inout [Float]) {
    // multiply by window function
    vDSP_vmul(audio, 1, window, 1, &audio, 1, vDSP_Length(n))
    
    // vDSP autocorrelation
    
    // convert real input to even-odd
    audio.withUnsafeBytes {
      let audioBP = $0.bindMemory(to: DSPComplex.self)
      vDSP_ctoz(audioBP.baseAddress!, 2, &A, 1, vDSP_Length(nOver2))
    }
    
    // fft
    vDSP_fft_zrip(fftSetup, &A, 1, vDSP_Length(log2n), FFTDirection(FFT_FORWARD))
    
    // Absolute square (equivalent to mag^2)
    vDSP_zvmags(&A, 1, A.realp, 1, vDSP_Length(nOver2))
    vDSP_vclr(A.imagp, 1, vDSP_Length(nOver2))
    
    // take cube roots of power spectrum
    for i in 0 ..< Int(nOver2) {
      Areal[i] = powf(Areal[i], 1.0 / 3.0)
    }
    
    // Inverse FFT
    vDSP_fft_zrip(fftSetup, &A, 1, vDSP_Length(log2n), FFTDirection(FFT_INVERSE))
    
    // convert complex split to real
    audio.withUnsafeMutableBytes {
      let audioBP = $0.bindMemory(to: DSPComplex.self)
      vDSP_ztoc(&A, 1, audioBP.baseAddress!, 2, vDSP_Length(nOver2))
    }
    
    // compute enhanced autocorrelation
    for i in 0 ..< Int(nOver2) {
      if (audio[i] < 0) {
        audio[i] = 0
      }
      work[i] = audio[i]
    }
    
    // octave error removal
    for i in 0 ..< Int(nOver2) {
      if ((i % 2) == 0) {
        audio[i] -= work[i / 2]
      }
      else {
        audio[i] -= ((work[i / 2] + work[i / 2 + 1]) / 2)
      }
    }
    for i in 0 ..< Int(nOver2) {
      if (audio[i] < 0) {
        audio[i] = 0
      }
      work[i] = audio[i]
    }
    
    // remove fifths
    for i in 0 ..< Int(nOver2) {
      switch (i%3) {
      case 0: audio[i] -= work[i / 3]
      case 1: audio[i] -= ((2*work[i / 3] + work[i / 3 + 1]) / 3)
      case 2: audio[i] -= ((work[i / 3] + 2*work[i / 3 + 1]) / 3)
      default: break
      }
    }
    for i in 0 ..< Int(nOver2) {
      if (audio[i] < 0) {
        audio[i] = 0
      }
    }
    
    // on exit, the vector audio contains the EAC (Enhanced Autocorrelation)
  }
  
  private func dominantFrequency(cut: [[Float]], sampleRate: Float) -> (Float,Float)? {
    var avEAC: [Float] = Array(repeating: 0, count: Int(n))
    
    // compute average from cut
    vDSP_vclr(&avEAC, 1, vDSP_Length(n))
    for slice in cut {
      vDSP_vadd(avEAC, 1, slice, 1, &avEAC, 1, vDSP_Length(n))
    }
    var count = Float(cut.count)
    vDSP_vsdiv(avEAC, 1, &count, &avEAC, 1, vDSP_Length(n))
    
    // find dominant frequency
    let maxDominantFrequency = lowAFrequency * 16
    let minDominantFrequency = lowAFrequency
    let maxDomBin = Int(sampleRate / minDominantFrequency)
    let minDomBin = Int(sampleRate / maxDominantFrequency)
    var bestBin: Int
    
    bestBin = minDomBin
    for i in minDomBin ..< maxDomBin {
      if (avEAC[i] > avEAC[bestBin]) {
        bestBin = i
      }
    }
    
    guard let (period,power) = findNearestPeak(audio: avEAC, bin: bestBin) else { return nil }
    
    return (sampleRate / period, power)
  }
  
  private func findNearestPeak(audio: [Float], bin: Int) -> (Float,Float)? {
    let leftbin = bin - 2
    if (leftbin >= 0 && leftbin+3 < audio.count) {
      guard let (thispeak,valueAtMax) = CubicMaximize(y0: audio[leftbin],
                                                      y1: audio[leftbin + 1],
                                                      y2: audio[leftbin + 2],
                                                      y3: audio[leftbin + 3]) else { return nil }
      return (thispeak+Float(leftbin),valueAtMax)
    }
    return nil
  }
  
  private func CubicMaximize(y0: Float, y1: Float, y2: Float, y3: Float) -> (Float,Float)? {
    // Find coefficients of cubic
    
    if y0 == y1 && y1 == y2 && y2 == y3 {
      return (0,y0)
    }
    
    var a, b, c, d: Float
    
    a = y0 / -6.0 + y1 / 2.0 - y2 / 2.0 + y3 / 6.0
    b = y0 - 5.0 * y1 / 2.0 + 2.0 * y2 - y3 / 2.0
    c = -11.0 * y0 / 6.0 + 3.0 * y1 - 3.0 * y2 / 2.0 + y3 / 3.0
    d = y0
    
    // Take derivative
    
    var da, db, dc: Float
    
    da = 3 * a
    db = 2 * b
    dc = c
    
    // Find zeroes of derivative using quadratic equation
    
    let discriminant = db * db - 4 * da * dc
    if (discriminant < 0.0) {
      return nil              // error
    }
    
    let x1 = (-db + sqrt(discriminant)) / (2 * da)
    let x2 = (-db - sqrt(discriminant)) / (2 * da)
    
    // The one which corresponds to a local _maximum_ in the
    // cubic is the one we want - the one with a negative
    // second derivative
    
    let dda = 2 * da
    let ddb = db
    
    if (dda * x1 + ddb < 0)
    {
      let max = a*x1*x1*x1+b*x1*x1+c*x1+d
      return (x1,max)
    }
    else
    {
      let max = a*x2*x2*x2+b*x2*x2+c*x2+d
      return (x2,max)
    }
  }
}
