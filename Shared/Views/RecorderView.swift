import SwiftUI

private let minimumDuration: Double = 2

struct RecorderView: View {
  @StateObject private var conductor = Current.conductor
  
  let onComplete: (URL?) -> Void
  var body: some View {
    VStack {
      Group {
        Spacer()
        Text(conductor.state.string)
          .font(.title)
      }
      Group {
        Spacer()
        Button(action: { conductor.state = .recording }) {
          Text("Record")
            .frame(maxWidth: .infinity, maxHeight: 50)
        }
        .buttonStyle(.bordered)
        .disabled(!conductor.state.isStopped)
      }
      Group {
        Spacer()
        Button(action: { conductor.state = .playing(nil) }) {
          Text("Play")
            .frame(maxWidth: .infinity, maxHeight: 50)
        }
        .buttonStyle(.bordered)
        .disabled(!conductor.state.isStopped)
      }
      Spacer()
      Button(action: { conductor.state = .stopped }) {
        Text("Stop")
          .frame(maxWidth: .infinity, maxHeight: 50)
      }
      .buttonStyle(.bordered)
      .disabled(conductor.state.isStopped)
      Spacer()
      HStack {
        Spacer()
        Button(action: { onComplete(nil) }) {
          Text("Cancel")
            .frame(maxWidth: .infinity, maxHeight: 50)
        }
        .buttonStyle(.bordered)
        .disabled(!conductor.state.isStopped)
        Spacer()
        Button(action: {
          if let recordedDuration = conductor.recorder?.recordedDuration,
             recordedDuration > minimumDuration {
            onComplete(conductor.recorder?.audioFile?.url)
          } else {
            onComplete(nil)
          }
        }) {
          Text("Done")
            .frame(maxWidth: .infinity, maxHeight: 50)
        }
        .buttonStyle(.bordered)
        .disabled(!conductor.state.isStopped)
        Spacer()
      }
      Spacer()
    }
    .padding()
    .onAppear {
      do {
        try conductor.recorder?.reset()
      } catch {
        print(error)
      }
    }
    .onDisappear {
      conductor.state = .stopped
    }
  }
}
