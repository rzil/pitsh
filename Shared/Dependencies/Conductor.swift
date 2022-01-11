//
//  Conductor.swift
//  pitsh
//
//  Created by Ruben Zilibowitz on 23/12/2021.
//

import AudioKit
import AudioKitEX
import AVFoundation
import Foundation

enum RecorderState {
  case recording
  case playing(URL?)
  case stopped
  init() {
    self = .stopped
  }
  var string: String {
    switch self {
    case .recording: return "Recording"
    case .playing: return "Playing"
    case .stopped: return "Stopped"
    }
  }
  var isStopped: Bool {
    if case .stopped = self {
      return true
    }
    return false
  }
  var isPlaying: Bool {
    if case .playing = self {
      return true
    }
    return false
  }
}

class Conductor: ObservableObject {
  let engine = AudioEngine()
  private(set) var recorder: NodeRecorder?
  let player = AudioPlayer()

  @Published var state = RecorderState() {
    didSet {
      if let recorder = self.recorder,
         recorder.isRecording == true {
        recorder.stop()
      }
      do {
        switch state {
        case .recording:
          NodeRecorder.removeTempFiles()
          try recorder?.record()
        case .playing(let url):
          if let sourceURL = url ?? recorder?.audioFile?.url {
            try player.file = AVAudioFile(forReading: sourceURL)
            player.completionHandler = {
              DispatchQueue.main.async { [weak self] in
                self?.state = .stopped
              }
            }
            player.play()
          }
        case .stopped:
          if player.isPlaying {
            player.stop()
          }
        }
      } catch {
        print(error)
      }
    }
  }

  init() {
    #if os(iOS)
    do {
        Settings.bufferLength = .short
        try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(Settings.bufferLength.duration)
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                        options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
        try AVAudioSession.sharedInstance().setActive(true)
    } catch let err {
        print(err)
    }
    #endif

    guard let input = engine.input else {
      fatalError()
    }

    do {
      recorder = try NodeRecorder(node: input)
    } catch let err {
      fatalError("\(err)")
    }
    engine.output = player
    NodeRecorder.removeTempFiles()
  }

  func start() {
    do {
      try engine.start()
    } catch let err {
      print(err)
    }
  }

  func stop() {
    engine.stop()
  }
}
