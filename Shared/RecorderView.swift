import AudioKit
import AudioKitEX
import SwiftUI
import AVFoundation

private enum RecorderState {
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

private class RecorderConductor: ObservableObject {
  let engine = AudioEngine()
  var recorder: NodeRecorder?
  let player = AudioPlayer()
  var silencer: Fader?
  let mixer = Mixer()

  @Published var state = RecorderState() {
    didSet {
      guard oldValue != state else { return }
      do {
        if state == .recording {
          NodeRecorder.removeTempFiles()
          try recorder?.record()
        } else if let recorder = self.recorder {
          if recorder.isRecording == true {
            recorder.stop()
          }
        }

        if state == .playing {
          if let sourceURL = recorder?.audioFile?.url {
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

struct RecorderView: View {
  @StateObject private var conductor = RecorderConductor()

  let onComplete: (URL?) -> Void
  var body: some View {
    VStack {
      Spacer()
      Text(conductor.state.string)
      Spacer()
      Button(action: { conductor.state = .recording }) {
        Text("Record")
      }
      .disabled(conductor.state != .stopped)
      Spacer()
      Button(action: { conductor.state = .playing }) {
        Text("Play")
      }
      .disabled(conductor.state != .stopped)
      Spacer()
      Button(action: { conductor.state = .stopped }) {
        Text("Stop")
      }
      .disabled(conductor.state == .stopped)
      Spacer()
      Button(action: { onComplete(conductor.recorder?.audioFile?.url) }) {
        Text("Done")
      }
      .disabled(conductor.state != .stopped)
    }
    .padding()
    .onAppear {
      conductor.start()
    }
    .onDisappear {
      conductor.stop()
    }
  }
}