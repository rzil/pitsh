//
//  PitchShifter.swift
//  Nika
//
//  Created by Ruben Zilibowitz on 24/2/19.
//  Copyright © 2019 Ruben Zilibowitz. All rights reserved.
//

/* This code is based on the function smbPitchShift by Stephen M Bernsee.
 It has been modified to use the Accelerate framework. The following
 license and copyright notice relates to the original code which is
 available here http://blogs.zynaptiq.com/bernsee/pitch-shifting-using-the-ft/ */

/*
 * COPYRIGHT 1999-2015 Stephan M. Bernsee <s.bernsee [AT] zynaptiq [DOT] com>
 *
 *                         The Wide Open License (WOL)
 *
 * Permission to use, copy, modify, distribute and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice and this license appear in all source copies.
 * THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED WARRANTY OF
 * ANY KIND. See http://www.dspguru.com/wol.htm for more information.
 */

import Foundation
import Accelerate

class PitchShifter {
  let fftSetup: FFTSetup
  let logBase2n, fftFrameSize, fftFrameSizeOver2: UInt32
  
  let window: [Float]
  
  var A: COMPLEX_SPLIT!
  var Areal: [Float]
  var Aimag: [Float]
  
  var oversampling: Int
  var sampleRate: Float
  
  var stepSize: Int { return Int(fftFrameSize) / oversampling }
  
  let minimumPower:Float = 120
  
  init?(logN: UInt32 = 12, oversampling:Int = 32, sampleRate:Float = 44100) {
    logBase2n = logN
    fftFrameSize = 1 << logBase2n
    fftFrameSizeOver2 = fftFrameSize / 2
    self.oversampling = oversampling
    self.sampleRate = sampleRate
    
    Areal = Array(repeating: 0, count: Int(fftFrameSize))
    Aimag = Array(repeating: 0, count: Int(fftFrameSize))
    guard let fftSetup = vDSP_create_fftsetup(vDSP_Length(logBase2n), FFTRadix(FFT_RADIX2)) else { return nil }
    self.fftSetup = fftSetup
    
    var window = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    vDSP_hann_window(&window, vDSP_Length(fftFrameSize), Int32(vDSP_HANN_NORM))
    //        vDSP_hamm_window(&window, vDSP_Length(fftFrameSize), 0)
    //        vDSP_blkman_window(&window, vDSP_Length(fftFrameSize), 0)
    //        for k in 0 ..< Int(fftFrameSize) {
    //            window[k] = -0.5 * cos(2 * .pi * Float(k) / Float(fftFrameSize)) + 0.5
    //        }
    self.window = window
    
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
  
  var pitchTrack: [Float]?
  var powerTrack: [Float]?
  
  var finalPitchTrack: [Float]?
  
  // simply copy a vector to another vector
  private func dsp_copy(input: UnsafePointer<Float>, output: inout [Float], length: vDSP_Length) {
    var _B: Float = 1
    vDSP_vsmul(input, 1, &_B, &output, 1, length)
  }
  
  func computePitchTrack(indata:[Float]) {
    var inFIFO = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    let outFIFO = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    var rover: Int = 0
    var inFifoLatency: Int
    
    let numSampsToProcess = indata.count
    
    var outdata = Array<Float>(repeating: 0, count: numSampsToProcess)
    
    /* set up some handy variables */
    let stepSize = self.stepSize
    inFifoLatency = Int(fftFrameSize) - stepSize
    if (rover == 0) { rover = inFifoLatency }
    
    let size = numSampsToProcess / stepSize + 1
    var pitchTrack = Array<Float>(repeating: 440, count: size)
    var powerTrack = Array<Float>(repeating: 0, count: size)
    
    var pitchTrackIndex: Int = 0
    
    /* main processing loop */
    for i in 0 ..< numSampsToProcess {
      
      /* As long as we have not yet collected enough data just read in */
      inFIFO[rover] = indata[i]
      outdata[i] = outFIFO[rover-inFifoLatency]
      rover += 1
      
      /* now we have enough data for processing */
      if rover >= fftFrameSize {
        rover = inFifoLatency
        
        let (ff,fp) = fundamentalFrequency(audio: inFIFO) ?? (440,0)
        pitchTrack[pitchTrackIndex] = ff
        powerTrack[pitchTrackIndex] = fp
        pitchTrackIndex += 1
        inFIFO.withUnsafeBufferPointer {
          dsp_copy(input: $0.baseAddress! + stepSize, output: &inFIFO, length: vDSP_Length(inFifoLatency))
        }
      }
    }
    
    self.pitchTrack = pitchTrack
    self.powerTrack = powerTrack
    //        self.finalPitchTrack = Array(repeating: 440, count: pitchTrackIndex)
    //        self.finalPitchTrack = pitchTrack
  }
  
  func process(pitchShift:Float? = nil, indata:[Float]) -> [Float] {
    var inFIFO = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    var outFIFO = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    var lastPhase = Array<Float>(repeating: 0, count: Int(fftFrameSizeOver2 + 1))
    var sumPhase = Array<Float>(repeating: 0, count: Int(fftFrameSizeOver2 + 1))
    var outputAccum = Array<Float>(repeating: 0, count: Int(2*fftFrameSize))
    var anaFreq = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    var anaMagn = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    var synFreq = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    var synMagn = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    var rover: Int = 0
    var tmp: Float
    var freqPerBin, expct: Float
    //      var qpd: Int
    var inFifoLatency: Int
    
    var work = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    //        var work2 = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    var workComplex = Array<DSPComplex>(repeating: DSPComplex(real: 0, imag: 0), count: Int(fftFrameSizeOver2))
    
    let numSampsToProcess = indata.count
    
    var outdata = Array<Float>(repeating: 0, count: numSampsToProcess)
    
    /* set up some handy variables */
    let stepSize = self.stepSize
    freqPerBin = sampleRate / Float(fftFrameSize)
    expct = 2 * .pi * Float(stepSize) / Float(fftFrameSize)
    inFifoLatency = Int(fftFrameSize) - stepSize
    if (rover == 0) { rover = inFifoLatency }
    
    var pitchTrackIndex: Int = 0
    
    /* main processing loop */
    for i in 0 ..< numSampsToProcess {
      
      /* As long as we have not yet collected enough data just read in */
      inFIFO[rover] = indata[i]
      outdata[i] = outFIFO[rover-inFifoLatency]
      rover += 1
      
      /* now we have enough data for processing */
      if rover >= fftFrameSize {
        rover = inFifoLatency
        
        // calculate pitch correction factor
        var pitchCorrection: Float
        if let pitchTrack = pitchTrack, let finalPitchTrack = finalPitchTrack, let powerTrack = powerTrack {
          //                    let pitchShift = finalPitchTrack[pitchTrackIndex] - pitchTrack[pitchTrackIndex]
          //                    pitchCorrection = pow(2, pitchShift / 12)
          if powerTrack[pitchTrackIndex] > 1 {
            pitchCorrection = finalPitchTrack[pitchTrackIndex] / pitchTrack[pitchTrackIndex]
          }
          else {
            pitchCorrection = 1
          }
          pitchTrackIndex += 1
        }
        else {
          pitchCorrection = pitchShift ?? 1
        }
        
        /* do windowing and re,im preparation for fft */
        vDSP_vmul(inFIFO, 1, window, 1, &work, 1, vDSP_Length(fftFrameSize))
        do {
          work.withUnsafeBytes {
            let workBP = $0.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(workBP.baseAddress!, 2, &A, 1, vDSP_Length(fftFrameSizeOver2))
          }
        }
        
        // vectorised version of fractional mod into range [-m/2,m/2)
        // eg 3 mod 5 == -2
        // eg 2 mod 5 == 2
        func dsp_mod(input: [Float], mod: Float, output: inout [Float], length: vDSP_Length) {
          var s: Float
          
          // first mod
          s = 1 / mod; vDSP_vsmul(input, 1, &s, &output, 1, length)
          vDSP_vfrac(output, 1, &output, 1, length)
          s = mod; vDSP_vsmul(output, 1, &s, &output, 1, length)
          
          // second mod into range [-m/2,m/2)
          s = mod * 1.5; vDSP_vsadd(output, 1, &s, &output, 1, length)
          s = 1 / mod; vDSP_vsmul(output, 1, &s, &output, 1, length)
          vDSP_vfrac(output, 1, &output, 1, length)
          s = mod; vDSP_vsmul(output, 1, &s, &output, 1, length)
          s = -mod * 0.5; vDSP_vsadd(output, 1, &s, &output, 1, length)
          
          // n.b. two mod operations are needed in order to handle negatives
        }
        
        // input_i = input_i + i*k
        func dsp_rampAdd(input: [Float], k: Float, output: inout [Float], length: vDSP_Length) {
          var _A: Float = 0
          var _B: Float = k
          
          vDSP_vramp(&_A, &_B, &output, 1, length)
          vDSP_vadd(input, 1, output, 1, &output, 1, length)
        }
        
        /* ***************** ANALYSIS ******************* */
        /* do transform */
        vDSP_fft_zrip(fftSetup, &A, 1, vDSP_Length(logBase2n), FFTDirection(FFT_FORWARD))
        
        // magnitudes
        vDSP_zvabs(&A, 1, &anaMagn, 1, vDSP_Length(fftFrameSizeOver2))
        
        // phases
        vDSP_zvphas(&A, 1, &anaFreq, 1, vDSP_Length(fftFrameSizeOver2))
        
        /* compute phase difference */
        vDSP_vsub(lastPhase, 1, anaFreq, 1, &work, 1, vDSP_Length(fftFrameSizeOver2))
        dsp_copy(input: anaFreq, output: &lastPhase, length: vDSP_Length(fftFrameSizeOver2))
        
        /* subtract expected phase difference */
        dsp_rampAdd(input: work, k: -expct, output: &work, length: vDSP_Length(fftFrameSizeOver2))
        
        /* map delta phase into +/- Pi interval */
        dsp_mod(input: work, mod: 2 * .pi, output: &work, length: vDSP_Length(fftFrameSizeOver2))
        
        /* get deviation from bin frequency from the +/- Pi interval */
        tmp = freqPerBin * Float(oversampling) / (2 * .pi)
        vDSP_vsmul(work, 1, &tmp, &work, 1, vDSP_Length(fftFrameSizeOver2))
        
        /* compute the k-th partials' true frequency */
        dsp_rampAdd(input: work, k: freqPerBin, output: &anaFreq, length: vDSP_Length(fftFrameSizeOver2))
        
        /* ***************** PROCESSING ******************* */
        /* this does the actual pitch shifting */
        vDSP_vclr(&synMagn, 1, vDSP_Length(fftFrameSize))
        vDSP_vclr(&synFreq, 1, vDSP_Length(fftFrameSize))
        for k in 0 ..< Int(fftFrameSizeOver2) {
          let index = Int(round(Float(k) * pitchCorrection))
          if 0 <= index && index < Int(fftFrameSizeOver2) {
            synMagn[index] += anaMagn[k]
            synFreq[index] = anaFreq[k] * pitchCorrection
          }
        }
        
        /* ***************** SYNTHESIS ******************* */
        /* this is the synthesis step */
        do {
          var _B: Float
          
          /* subtract bin mid frequency */
          dsp_rampAdd(input: synFreq, k: -freqPerBin, output: &work, length: vDSP_Length(fftFrameSizeOver2))
          
          /* get bin deviation from freq deviation */
          _B = 1 / freqPerBin
          vDSP_vsmul(work, 1, &_B, &work, 1, vDSP_Length(fftFrameSizeOver2))
          
          /* take oversampling into account */
          _B = 2 * .pi / Float(oversampling)
          vDSP_vsmul(work, 1, &_B, &work, 1, vDSP_Length(fftFrameSizeOver2))
          
          /* add the overlap phase advance back in */
          dsp_rampAdd(input: work, k: expct, output: &work, length: vDSP_Length(fftFrameSizeOver2))
          
          /* accumulate delta phase to get bin phase */
          vDSP_vadd(sumPhase, 1, work, 1, &sumPhase, 1, vDSP_Length(fftFrameSizeOver2))
          
          // mod by 2*pi into range (-pi , pi)
          dsp_mod(input: sumPhase, mod: 2 * .pi, output: &sumPhase, length: vDSP_Length(fftFrameSizeOver2))
          
          /* get real and imag part and re-interleave */
          synMagn.withUnsafeMutableBufferPointer { synMagnBP in
            sumPhase.withUnsafeMutableBufferPointer { sumPhaseBP in
              var splitComplex = DSPSplitComplex(realp: synMagnBP.baseAddress!, imagp: sumPhaseBP.baseAddress!)
              vDSP_ztoc(&splitComplex, 1, &workComplex, 2, vDSP_Length(fftFrameSizeOver2))
              workComplex.withUnsafeBytes {
                let workComplexCast = $0.bindMemory(to: Float.self)
                vDSP_rect(workComplexCast.baseAddress!, 2, &work, 2, vDSP_Length(fftFrameSizeOver2))
              }
            }
          }
        }
        
        /* prepare for fft */
        work.withUnsafeBytes {
          let workBP = $0.bindMemory(to: DSPComplex.self)
          vDSP_ctoz(workBP.baseAddress!, 2, &A, 1, vDSP_Length(fftFrameSizeOver2))
        }
        
        /* zero negative frequencies */
        Areal.withUnsafeMutableBufferPointer {
          vDSP_vclr($0.baseAddress! + Int(fftFrameSizeOver2), 1, vDSP_Length(fftFrameSizeOver2))
        }
        Aimag.withUnsafeMutableBufferPointer {
          vDSP_vclr($0.baseAddress! + Int(fftFrameSizeOver2), 1, vDSP_Length(fftFrameSizeOver2))
        }
        
        /* do inverse transform */
        vDSP_fft_zip(fftSetup, &A, 1, vDSP_Length(logBase2n), FFTDirection(FFT_INVERSE))
        dsp_copy(input: Areal, output: &work, length: vDSP_Length(fftFrameSize))
        
        /* do windowing and add to output accumulator */
        vDSP_vmul(work, 1, window, 1, &work, 1, vDSP_Length(fftFrameSize))
        tmp = 2/Float(Int(fftFrameSizeOver2) * oversampling)
        vDSP_vsmul(work, 1, &tmp, &work, 1, vDSP_Length(fftFrameSize))
        vDSP_vadd(outputAccum, 1, work, 1, &outputAccum, 1, vDSP_Length(fftFrameSize))
        dsp_copy(input: outputAccum, output: &outFIFO, length: vDSP_Length(stepSize))
        
        /* shift accumulator */
        outputAccum.withUnsafeBufferPointer {
          dsp_copy(input: $0.baseAddress! + stepSize, output: &outputAccum, length: vDSP_Length(fftFrameSize))
        }
        
        /* move input FIFO */
        inFIFO.withUnsafeBufferPointer {
          dsp_copy(input: $0.baseAddress! + stepSize, output: &inFIFO, length: vDSP_Length(inFifoLatency))
        }
      }
    }
    
    return outdata
  }
  
  private func fundamentalFrequency(audio: [Float]) -> (frequency: Float, power: Float)? {
    var audio = audio
    autocorrelation(audio: &audio)
    guard let (f,p) = dominantFrequency(eac: audio, sampleRate: sampleRate) else { return nil }
    if p > minimumPower {
      return (f,p)
    }
    else {
      return (-1,p)
    }
  }
  
  private func autocorrelation(audio: inout [Float]) {
    var work = Array<Float>(repeating: 0, count: Int(fftFrameSize))
    
    // multiply by window function
    vDSP_vmul(audio, 1, window, 1, &audio, 1, vDSP_Length(fftFrameSize))
    
    // vDSP autocorrelation
    
    // convert real input to even-odd
    audio.withUnsafeBytes {
      let audioBP = $0.bindMemory(to: DSPComplex.self)
      vDSP_ctoz(audioBP.baseAddress!, 2, &A, 1, vDSP_Length(fftFrameSizeOver2))
    }
    
    // fft
    vDSP_fft_zrip(fftSetup, &A, 1, vDSP_Length(logBase2n), FFTDirection(FFT_FORWARD))
    
    // Absolute square (equivalent to mag^2)
    vDSP_zvmags(&A, 1, A.realp, 1, vDSP_Length(fftFrameSizeOver2))
    vDSP_vclr(A.imagp, 1, vDSP_Length(fftFrameSizeOver2))
    
    // take cube roots of power spectrum
    for i in 0 ..< Int(fftFrameSizeOver2) {
      Areal[i] = powf(Areal[i], 1.0 / 3.0)
    }
    
    // Inverse FFT
    vDSP_fft_zrip(fftSetup, &A, 1, vDSP_Length(logBase2n), FFTDirection(FFT_INVERSE))
    
    // convert complex split to real
    audio.withUnsafeMutableBytes {
      let audioBP = $0.bindMemory(to: DSPComplex.self)
      vDSP_ztoc(&A, 1, audioBP.baseAddress!, 2, vDSP_Length(fftFrameSizeOver2))
    }
    
    // compute enhanced autocorrelation
    for i in 0 ..< Int(fftFrameSizeOver2) {
      if (audio[i] < 0) {
        audio[i] = 0
      }
      work[i] = audio[i]
    }
    
    // octave error removal
    for i in 0 ..< Int(fftFrameSizeOver2) {
      if ((i % 2) == 0) {
        audio[i] -= work[i / 2]
      }
      else {
        audio[i] -= ((work[i / 2] + work[i / 2 + 1]) / 2)
      }
    }
    for i in 0 ..< Int(fftFrameSizeOver2) {
      if (audio[i] < 0) {
        audio[i] = 0
      }
      work[i] = audio[i]
    }
    
    // remove fifths
    for i in 0 ..< Int(fftFrameSizeOver2) {
      switch (i%3) {
      case 0: audio[i] -= work[i / 3]
      case 1: audio[i] -= ((2*work[i / 3] + work[i / 3 + 1]) / 3)
      case 2: audio[i] -= ((work[i / 3] + 2*work[i / 3 + 1]) / 3)
      default: break
      }
    }
    for i in 0 ..< Int(fftFrameSizeOver2) {
      if (audio[i] < 0) {
        audio[i] = 0
      }
    }
    
    // on exit, the vector audio contains the EAC (Enhanced Autocorrelation)
  }
  
  private func dominantFrequency(eac: [Float], sampleRate: Float) -> (frequency: Float, power: Float)? {
    let lowAFrequency: Float = 55
    
    // find dominant frequency
    let maxDominantFrequency = lowAFrequency * 16
    let minDominantFrequency = lowAFrequency
    let maxDomBin = Int(sampleRate / minDominantFrequency)
    let minDomBin = Int(sampleRate / maxDominantFrequency)
    var bestBin: Int
    
    bestBin = minDomBin
    for i in minDomBin ..< maxDomBin {
      if (eac[i] > eac[bestBin]) {
        bestBin = i
      }
    }
    
    guard let (period,power) = findNearestPeak(audio: eac, bin: bestBin) else { return nil }
    
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
