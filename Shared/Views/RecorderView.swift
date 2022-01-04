import SwiftUI

struct RecorderView: View {
  @StateObject private var conductor = Current.conductor
  
  let onComplete: (URL?) -> Void
  var body: some View {
    VStack {
      Group {
        Spacer()
        Text(conductor.state.string)
      }
      Spacer()
      Button(action: { conductor.state = .recording }) {
        Text("Record")
      }
      .disabled(!conductor.state.isStopped)
      Spacer()
      Button(action: { conductor.state = .playing(nil) }) {
        Text("Play")
      }
      .disabled(!conductor.state.isStopped)
      Spacer()
      Button(action: { conductor.state = .stopped }) {
        Text("Stop")
      }
      .disabled(conductor.state.isStopped)
      Spacer()
      Button(action: {
        if let recordedDuration = conductor.recorder?.recordedDuration,
           recordedDuration > 0 {
          onComplete(conductor.recorder?.audioFile?.url)
        } else {
          onComplete(nil)
        }
      }) {
        Text("Done")
      }
      .disabled(!conductor.state.isStopped)
      Spacer()
    }
    .padding()
    .onAppear(perform: {
      do {
        try conductor.recorder?.reset()
      } catch {
        print(error)
      }
    })
  }
}
