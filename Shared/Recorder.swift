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
      do {
        let document = try Current.coreData.getDocument()
        if data.isRecording {
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
            }
          }
        }
        
        if data.isPlaying {
          if let sourceURL = document.audioFileURL,
             let destinationURL = document.shiftedAudioFileURL {
            print("** shifting...")
            try shiftAudioURL(sourceURL, outputURL: destinationURL)
            print("** done shifting")
            try player.file = AVAudioFile(forReading: destinationURL)
            player.play()
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
