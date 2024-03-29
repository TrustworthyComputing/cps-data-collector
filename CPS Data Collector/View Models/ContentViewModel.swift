import Foundation
import CoreMotion
import SwiftUI
import AVFoundation
import DSWaveformImage


class ContentViewModel: NSObject, ObservableObject{
    private let motion = CMMotionManager()
    private var accelerometerTimer: Timer? = nil
    private var graphTimer: Timer? = nil
    private var recordingTimer: Timer? = nil
    private var audioTimer: Timer? = nil
    private let movieOutput = AVCaptureMovieFileOutput()
    private var previewLayer = AVCaptureVideoPreviewLayer()
    private var recordingSession = AVAudioSession()
    private var audioRecorder = AVAudioRecorder()
    private var outputURL: URL? = nil
    private var csvData : [[String]] =  [["TimeStamp","X","Y","Z"]]
    private let dateFormatter = DateFormatter()
    private var recordDuration = 0
    private var audioInput: AVCaptureDeviceInput?
    let metadataOutput = AVCaptureMetadataOutput()
    
    var captureSession = AVCaptureSession()
    @Published var trackingData = [TrackingData]()
    @Published var isRecording = false
    @Published var recordingDuration: String = ""
    @Published var audioData = [AudioData]()
    @Published var recordDate = Date()
    
    var enableVideoRecording: Bool = false
    var enableAudioRecording: Bool = false
    var enableMotionManager: Bool = false
    
    
    override init() {
        super.init()
        DispatchQueue.global(qos: .background).async{
            self.configureCamera()
        }
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
    }
    
    
    func startOperation(isVideoEnabled: Bool,isAudioEnabled: Bool, isAccelerometerEnabled: Bool){
        
        if isAccelerometerEnabled{
            startAccelerometers()
        }
        if isAudioEnabled || isVideoEnabled{
            startRecording(shouldRecordVideo: isVideoEnabled, shouldAudioEnabled: isAudioEnabled)
        }
        isRecording = true
        UIApplication.shared.isIdleTimerDisabled = true
        getTrackingData()
        
        self.recordingTimer = Timer(fire: Date(), interval: 1,
                                    repeats: true, block: { (timer) in
            self.recordDuration += 1
            self.recordingDuration =  "\(self.recordDuration/60)m"
            
            
        })
        RunLoop.current.add(self.recordingTimer!, forMode: .default)
    }
    
    func stopOperation(){
        stopAcceleromenters()
        stopVideoRecording()
        isRecording = false
        UIApplication.shared.isIdleTimerDisabled = false
        self.graphTimer?.invalidate()
        recordDuration = 0
        self.recordingTimer?.invalidate()
    }
    
    func changeCameraSession(status: Bool){
        if status{
            DispatchQueue.global(qos: .background).async{
                self.captureSession.startRunning()
            }
        }
        else{
            DispatchQueue.global(qos: .background).async{
                self.captureSession.stopRunning()
            }
        }
    }
    
    private func startRecording(shouldRecordVideo: Bool, shouldAudioEnabled: Bool){
        
        if shouldRecordVideo{
            startVideoRecording(isAudioEnabled: shouldAudioEnabled)
        }
        else{
            captureSession.stopRunning()
            startAudioRecording()
        }
    }
    
    private func startAccelerometers() {
        if !motion.isAccelerometerActive{
            csvData = [["TimeStamp","X","Y","Z"]]
            // Make sure the accelerometer hardware is available.
            if self.motion.isAccelerometerAvailable {
                self.motion.accelerometerUpdateInterval = 1.0 / 200
                self.motion.startAccelerometerUpdates()
                
                // Configure a timer to fetch the data.
                self.accelerometerTimer = Timer(fire: Date(), interval: (1.0/200),
                                                repeats: true, block: { (timer) in
                    // Get the accelerometer data.
                    if let data = self.motion.accelerometerData {
                        let x = data.acceleration.x
                        let y = data.acceleration.y
                        let z = data.acceleration.z
                        self.csvData.append(["\(Date().timeIntervalSince1970)","\(x)","\(y)","\(z)"])
                    }
                })
                
                
                RunLoop.current.add(self.accelerometerTimer!, forMode: .default)
            }
        }
    }
    
    private func stopAcceleromenters(){
        
        if motion.isAccelerometerActive{
            self.accelerometerTimer?.invalidate()
            let currentDateTime = dateFormatter.string(from: Date())
            let fileName = "accelerometer_\(currentDateTime).csv"
            motion.stopAccelerometerUpdates()
            if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let folderURL = documentDirectory.appendingPathComponent("csv")
                let fileURL = folderURL.appendingPathComponent(fileName)
                // Create a string to store the CSV data.
                do{
                    if !FileManager.default.fileExists(atPath: folderURL.path){
                        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                    } else {
                        print("Already dictionary created.")
                    }
                }
                catch{
                    
                }
                var csvText = ""
                
                for row in csvData {
                    let rowText = row.joined(separator: ",") // Join columns with commas
                    csvText.append(rowText + "\n") // Append a new line for each row
                }
                do {
                    try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
                    print("CSV file saved to \(fileURL.path)")
                } catch {
                    print("Error writing CSV file: \(error)")
                }
            }
        }
    }
    
    private func getTrackingData(){
        recordDate = Date()
        self.trackingData = []
        self.graphTimer = Timer(fire: Date(), interval: (1.0/8),
                                repeats: true, block: { (timer) in
            // Get the accelerometer data.
            var x: Double = 0/0
            var y: Double  = 0/0
            var z: Double  = 0/0
            var adjustedAudioLevel: Double = 0
            
            if let data = self.motion.accelerometerData, self.motion.isAccelerometerActive {
                x = data.acceleration.x
                y = data.acceleration.y
                z = data.acceleration.z
            }
        

            
            if self.audioRecorder.isRecording{
                self.audioRecorder.updateMeters()
                let power = Double( self.audioRecorder.averagePower(forChannel: 0) + 160)
                adjustedAudioLevel = pow((power - 100)/11, 2.75)
            }
            
            self.trackingData.append(TrackingData(date: Date(), x: x,y: y,z: z, audioData: adjustedAudioLevel.isNaN ? 1 : adjustedAudioLevel))
            self.trackingData.removeAll(where: {$0.date.timeIntervalSinceNow < -30})
            print(self.trackingData.count)
            // Use the accelerometer data in your app.
        })
        // Add the timer to the current run loop.
        RunLoop.current.add(self.graphTimer!, forMode: .default)
    }
    
    private func configureCamera(){
        if let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video
                                                       , position: .back) {
            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                    try captureDevice.lockForConfiguration()
                    
                    captureDevice.activeFormat = captureDevice.formats[20]
                    captureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 60)
                    captureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 60)
                    
                    captureDevice.unlockForConfiguration()
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        
        
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }
        
//        if captureSession.canAddOutput(metadataOutput) {
//            captureSession.addOutput(metadataOutput)
//            metadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
//        }
//        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        self.captureSession.startRunning()
    }
    
    private func startVideoRecording(isAudioEnabled: Bool){
        
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let newAudioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if captureSession.canAddInput(newAudioInput) && isAudioEnabled{
                captureSession.addInput(newAudioInput)
                audioInput = newAudioInput
            }
            
            else if let existingAudioInput = audioInput ,!isAudioEnabled{
                captureSession.removeInput(existingAudioInput)
            }
            
        }
        
        
        if !movieOutput.isRecording {
            if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let videoFolderURL = documentDirectory.appendingPathComponent("video")
                let currentDateTime = dateFormatter.string(from: Date())
                outputURL = videoFolderURL.appendingPathComponent("vid_\(currentDateTime).mov")
                
                do{
                    if !FileManager.default.fileExists(atPath: videoFolderURL.path){
                        try FileManager.default.createDirectory(at: videoFolderURL, withIntermediateDirectories: true, attributes: nil)
                    } else {
                        print("Already dictionary created.")
                    }
                }
                catch{
                    
                }
                
                movieOutput.startRecording(to: outputURL!, recordingDelegate: self)
                captureSession.commitConfiguration()
                
            }
            
        }
    }
    
    func stopVideoRecording(){
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
        else{
            stopAudioRecording()
        }
    }
    
    private func startAudioRecording(){
        
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {return}
        let currentDateTime = dateFormatter.string(from: Date())
        let audioFolderURL = documentDirectory.appendingPathComponent("audios")
        let audioURL = audioFolderURL.appendingPathComponent("audio_\(currentDateTime).caf")
        do{
            if !FileManager.default.fileExists(atPath: audioFolderURL.path){
                try FileManager.default.createDirectory(at: audioFolderURL, withIntermediateDirectories: true, attributes: nil)
            } else {
                print("Already dictionary created.")
            }
        }
        catch{
            
        }
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC), // Change format as needed
            AVSampleRateKey: 44100.0, // Standard sample rate
            AVNumberOfChannelsKey: 1, // Stereo audio
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue // Audio quality
        ]
        
        do {
            recordingSession = AVAudioSession.sharedInstance()
            try recordingSession.setCategory(.record, mode: .default)
            try recordingSession.setActive(true)
            
            try audioRecorder = AVAudioRecorder(url: audioURL, settings: audioSettings)
            audioRecorder.prepareToRecord()
            
            audioRecorder.isMeteringEnabled  = true
            //audioRecorder.updateMeters()
            
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        
                        self.audioRecorder.record()
                    } else {
                        // failed to record!
                    }
                }
            }
            
        } catch {
            print(error.localizedDescription)
            // failed to record!
        }
    }
    
    private func stopAudioRecording() {
        //self.audioData = []
        audioTimer?.invalidate()
        audioRecorder.stop()
    }

}

extension ContentViewModel: AVCaptureFileOutputRecordingDelegate{
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("didFinishRecordingTo")
    }
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("didStartRecordingTo")
    }
    
}

extension ContentViewModel: AVAudioRecorderDelegate{
    
}

//extension ContentViewModel: AVCaptureMetadataOutputObjectsDelegate{
//    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
//        for metadataObject in metadataObjects {
//            if let qrCodeObject = metadataObject as? AVMetadataMachineReadableCodeObject {
//                if qrCodeObject.type == AVMetadataObject.ObjectType.qr,
//                   let qrCodeValue = qrCodeObject.stringValue {
//                    
//                    
//                    let qrCodeRect = previewLayer.metadataOutputRectConverted(fromLayerRect: qrCodeObject.bounds)
//                    print("QR Code detected: \(qrCodeRect)")
//                                    
//                                    // Draw a green rectangle around the QR code
////                                    if let qrCodeRect = qrCodeRect {
////                                        drawGreenRectangle(around: qrCodeRect.bounds, onLayer: previewLayer.layer)
////                                    }
//                }
//            }
//        }
//    }
//}
