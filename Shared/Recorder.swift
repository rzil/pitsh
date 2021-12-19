import AudioKit
import AudioKitEX
import SwiftUI
import AVFoundation

struct RecorderData {
  var isRecording = false
  var isPlaying = false
}

class RecorderConductor: ObservableObject {
  let engine = AudioEngine()
  var recorder: NodeRecorder?
  let player = AudioPlayer()
  var silencer: Fader?
  let mixer = Mixer()
  
  @Published var data = RecorderData() {
    didSet {
      if data.isRecording {
        NodeRecorder.removeTempFiles()
        do {
          try recorder?.record()
        } catch let err {
          print(err)
        }
      } else {
        recorder?.stop()
      }
      
      if data.isPlaying {
        if let file = recorder?.audioFile {
          let outputURL = URL(string: NSTemporaryDirectory())!.appendingPathComponent("shifted.aiff")
          print("** shifting...")
          try! shiftAudioURL(file.url, outputURL: outputURL)
          print("** done shifting")
          try! player.file = AVAudioFile(forReading: outputURL)
          player.play()
        }
      } else {
        player.stop()
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
      Text(conductor.data.isRecording ? "STOP RECORDING" : "RECORD").onTapGesture {
        self.conductor.data.isRecording.toggle()
      }
      Spacer()
      Text(conductor.data.isPlaying ? "STOP" : "PLAY").onTapGesture {
        self.conductor.data.isPlaying.toggle()
      }
      Spacer()
    }
    
    .padding()
//    .navigationBarTitle(Text("Recorder"))
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
