import SwiftUI
import MobileCoreServices
import Charts

struct ContentView: View {
    @ObservedObject var contentVM: ContentViewModel = ContentViewModel()
    @State var videoEnabled =  true
    @State var audioEnabled =  true
    @State var accelerometerEnabled =  true
    @State var trackingEnabled =  true
    @State var recordingEnabled =  true
    @State private var wavePhase: CGFloat = 0
    @State private var pitchAnimationOffset: CGFloat = 0
    @State var stoppedDate = Date()
    let dataPoints: [Double] = [10, 20, 30, 40, 50]
   
    var body: some View {
        
        VStack{
            HStack{
                Text("\(UIDevice.current.freeDiskSpaceInGB) Left")
                    .font(.system(size: 13))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.gray))
                Spacer()
                Text(contentVM.isRecording ?  "Recording \(contentVM.recordingDuration)" : "Ready")
                    .font(.system(size: 13))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 16).fill(contentVM.isRecording ? Color.red : Color.green))
            }
            .padding(.horizontal,16)
            .padding(.vertical,16)
            
            //ScrollView{
            GeometryReader{reader in
                VStack{
                    
                    if videoEnabled{
                        CameraPreviewHolder(captureSession: contentVM.captureSession)
                            .frame(width: reader.size.width, height: reader.size.height * 0.6)
                        
                    }
                    else if audioEnabled{
                        //Chart {
                        HStack{
                            Spacer()
                            HStack(alignment: .center, spacing: 3) {
                                let num = Int(UIScreen.main.bounds.width / 4.5)
                                ForEach(contentVM.trackingData.suffix(num), id: \.date) { item in
                                    Image(systemName: "rectangle.portrait.fill").resizable().foregroundColor(.red).frame(width: 1.5,height: item.audioData)
                                }
                                
                            }
                            
                            
                        }
                        .frame(width: reader.size.width, height: reader.size.height * 0.6)
                        
                    }
                    else{
                        Text("Video Preview Disabled").frame(width: reader.size.width, height: reader.size.height * 0.6).background(Rectangle().foregroundColor(.gray))
                    }
                    
                    if accelerometerEnabled{
                        
                        Chart {
                            ForEach(contentVM.trackingData, id: \.date) {item  in
                                LineMark(
                                    x: .value("", item.date.timeIntervalSince(contentVM.isRecording ? Date() : stoppedDate)),
                                    y: .value("X", item.x > 1 ? 1 : item.x < -1 ? -1 : item.x),
                                    series: .value("Accelerometer", "X")
                                )
                                .foregroundStyle(.cyan)
                                
                                
                                LineMark(
                                    x: .value("", item.date.timeIntervalSince(contentVM.isRecording ? Date() : stoppedDate)),
                                    y: .value("Y", item.y > 1 ? 1 : item.y < -1 ? -1 : item.y),
                                    series: .value("Accelerometer", "Y")
                                )
                                .foregroundStyle(.green)
                                
                                LineMark(
                                    x: .value("", item.date.timeIntervalSince(contentVM.isRecording ? Date() : stoppedDate)),
                                    y: .value("Z", item.z > 1 ? 1 : item.z < -1 ? -1 : item.z),
                                    series: .value("Accelerometer", "Z")
                                )
                                .foregroundStyle(.red)
                                
                            }
                        }
                        .chartXAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let seconds = value.as(Int.self){
                                        Text("\(-1 * seconds)s")
                                    }
                                    
                                }
                            }
                        }
                        .chartXScale(domain: -30...0)
                        .chartYScale(domain: -1...1)
                        
                        
                        .frame(height: reader.size.height * 0.35)
                    }
                }
            }
            
            
            //}.scrollIndicators(.hidden)
            
            HStack{
                TabButton(text: "Video", imageName: "camera", enabled: $videoEnabled){
                    if !contentVM.isRecording{
                        videoEnabled.toggle()
                    }
                    
                }
                TabButton(text: "Audio", imageName: "music.mic", enabled: $audioEnabled){
                    if !contentVM.isRecording{
                        audioEnabled.toggle()
                    }
                }
                
                if contentVM.isRecording{
                    TabButton(text: "Stop", imageName: "pause.fill" ,enabled: $recordingEnabled){
                        contentVM.stopOperation()
                    }
                    
                }
                else{
                    TabButton(text: "Start", imageName:  "play.fill",enabled: $recordingEnabled){
                        if audioEnabled || videoEnabled || accelerometerEnabled{
                            contentVM.startOperation(isVideoEnabled: videoEnabled, isAudioEnabled: audioEnabled, isAccelerometerEnabled: accelerometerEnabled)
                        }
                    }
                    
                }
                
                TabButton(text: "Accelerometer", imageName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left",enabled: $accelerometerEnabled){
                    if !contentVM.isRecording{
                        accelerometerEnabled.toggle()
                    }
                }
                
                TabButton(text: "Tracking", imageName: "point.topleft.down.curvedto.point.bottomright.up.fill",enabled: $trackingEnabled){
                }
                
            }.padding(.horizontal,16)
        }
        
        .onChange(of: videoEnabled) { newValue in
            recordingEnabled = newValue || audioEnabled || accelerometerEnabled
            contentVM.changeCameraSession(status: newValue)
        }
        .onChange(of: audioEnabled) { newValue in
            recordingEnabled = videoEnabled || newValue || accelerometerEnabled
        }
        .onChange(of: accelerometerEnabled) { newValue in
            recordingEnabled = videoEnabled || audioEnabled || newValue
        }
        .onChange(of: contentVM.isRecording) { newValue in
            if !newValue{
                stoppedDate = contentVM.trackingData.last?.date ?? Date()
            }
        }
    }
}

struct TabButton: View {
    
    @State var text: String
    @State var imageName: String
    @Binding var enabled: Bool
    //@State var color: Color
    @State var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(alignment: .center){
                Text(text)
                    .foregroundColor(enabled ? .green : .gray)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Image(systemName: imageName)
                    .font(.system(size: 24))
                    .foregroundColor(enabled ? .green : .gray)
            }
            .frame(width:  (UIScreen.main.bounds.width - 32) / 5 )
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
