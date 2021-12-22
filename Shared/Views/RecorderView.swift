import SwiftUI

struct RecorderView: View {
  @StateObject private var conductor = Current.conductor

  let onComplete: (URL?) -> Void
  var body: some View {
    VStack {
      Spacer()
      Text(conductor.state.string)
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
      Button(action: { onComplete(conductor.recorder?.audioFile?.url) }) {
        Text("Done")
      }
      .disabled(!conductor.state.isStopped)
    }
    .padding()
  }
}
