//
//  URL+AudioFile.swift
//  Pitsh
//
//  Created by Ruben Zilibowitz on 18/12/21.
//  Copyright © 2021 Ruben Zilibowitz. All rights reserved.
//

import Foundation
import AVFoundation

extension URL {
  func readAudioFile() throws -> (data: [Float], sampleRate: Double) {
    let file = try AVAudioFile(forReading: self)
    guard let data = file.toFloatChannelData(), let first = data.first else { throw AVError(.failedToLoadMediaData) }
    let sum = data.dropFirst().reduce(first, {result, next in zip(result, next).map(+)})
    let average = sum.map({$0 / Float(data.count)})
    return (data: average, sampleRate: file.fileFormat.sampleRate)
  }

  func writeAudioFile(_ buffer: [Float], sampleRate: Double) throws {
    let outputFormatSettings = [
      AVFormatIDKey:kAudioFormatLinearPCM,
      AVLinearPCMBitDepthKey:32,
      AVLinearPCMIsFloatKey: true,
      //  AVLinearPCMIsBigEndianKey: false,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: 1
    ] as [String : Any]
    
    let audioFile = try AVAudioFile(forWriting: self, settings: outputFormatSettings, commonFormat: AVAudioCommonFormat.pcmFormatFloat32, interleaved: false)
    let bufferFormat = AVAudioFormat(settings: outputFormatSettings)!
    let outputBuffer = AVAudioPCMBuffer(pcmFormat: bufferFormat, frameCapacity: AVAudioFrameCount(buffer.count))!
    for i in 0 ..< buffer.count {
      outputBuffer.floatChannelData!.pointee[i] = buffer[i]
    }
    outputBuffer.frameLength = AVAudioFrameCount( buffer.count )
    try audioFile.write(from: outputBuffer)
  }
}
