import AudioKit
import AudioKitEX
import SwiftUI
import AVFoundation

enum RecorderState {
  case recording
  case playing
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
}

class RecorderConductor: ObservableObject {
  let engine = AudioEngine()
  var recorder: NodeRecorder?
  let player = AudioPlayer()
  var silencer: Fader?
  let mixer = Mixer()

  @Published var state = RecorderState() {
    didSet {
      guard oldValue != state else { return }
      do {
        let document = try Current.coreData.getDocument()
        if state == .recording {
          NodeRecorder.removeTempFiles()
          try recorder?.record()
        } else if let recorder = self.recorder {
          if recorder.isRecording == true {
            recorder.stop()
            if let url = recorder.audioFile?.url,
               let destinationURL = document.audioFileURL {
              let fileManager = FileManager.default
              if fileManager.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
              }
              try FileManager.default.moveItem(at: url, to: destinationURL)
              print("*** tuning")
              DispatchQueue.global().async {
                do {
                  try document.performAutocorrelation { error in
                    print("*** done tuning: \(error?.localizedDescription ?? "no errors")")
                    print("*** event count \(document.eventsSorted?.count ?? -1)")
                  }
                } catch {
                  print(error)
                }
              }
            }
          }
        }

        if state == .playing {
          if let sourceURL = document.audioFileURL {
            try player.file = AVAudioFile(forReading: sourceURL)
            player.play()
            player.completionHandler = {
              DispatchQueue.main.async {
                self.state = .stopped
              }
            }
          }
        } else {
          player.stop()
        }
      } catch {
        print(error)
      }
    }
  }

  init() {
    guard let input = engine.input else {
      fatalError()
    }
    
    do {
      recorder = try NodeRecorder(node: input)
    } catch let err {
      fatalError("\(err)")
    }
    let silencer = Fader(input, gain: 0)
    self.silencer = silencer
    mixer.addInput(silencer)
    mixer.addInput(player)
    engine.output = mixer
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

struct RecorderView: View {
  @StateObject var conductor = RecorderConductor()

  var body: some View {
    VStack {
      Spacer()
      Text(conductor.state.string)
      Spacer()
      Text("Record")
        .bold()
        .disabled(conductor.state != .stopped)
        .foregroundColor(conductor.state != .stopped ? .gray : .black)
        .onTapGesture {
          self.conductor.state = .recording
        }
      Spacer()
      Text("Play")
        .bold()
        .disabled(conductor.state != .stopped)
        .foregroundColor(conductor.state != .stopped ? .gray : .black)
        .onTapGesture {
          self.conductor.state = .playing
        }
      Spacer()
      Text("Stop")
        .bold()
        .disabled(conductor.state == .stopped)
        .foregroundColor(conductor.state == .stopped ? .gray : .black)
        .onTapGesture {
          self.conductor.state = .stopped
        }
      Spacer()
    }

    .padding()
    .onAppear {
      self.conductor.start()
    }
    .onDisappear {
      self.conductor.stop()
    }
  }
}

private func shiftAudioURL(_ audioURL: URL, outputURL: URL) throws {
  let (floatData, sampleRate) = try audioURL.readAudioFile()
  guard let pitchShifter = PitchShifter(sampleRate: Float(sampleRate)) else { return }
  //      pitchShifter.pitchTrack = document.frequencies
  //      pitchShifter.powerTrack = document.powers
  //      pitchShifter.finalPitchTrack = pitchShifter.pitchTrack
  //      for ev in eventsSorted {
  //        let start = Int(ev.start)
  //        let end = Int(ev.end)
  //        let f = pow(2, (ev.effectivePitch + 3) / 12) * 55
  //        for i in start ..< end {
  //          pitchShifter.finalPitchTrack?[i] = f
  //        }
  //      }
  let shiftedAudio = pitchShifter.process(pitchShift: 1.2, indata: floatData)
  try outputURL.writeAudioFile(shiftedAudio, sampleRate: sampleRate)
}
