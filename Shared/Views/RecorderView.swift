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
