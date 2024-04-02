import UIKit
import AVFoundation
import CoreData

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate{
   
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var faceView: FaceView!
    @IBOutlet weak var resultView: UIView!
    
    
    @IBOutlet weak var enrolledView: UIView!
    @IBOutlet weak var enrolledImage: UIImageView!
    @IBOutlet weak var identifiedView: UIView!
    @IBOutlet weak var identifiedImage: UIImageView!

    @IBOutlet weak var enrolledNameLbl: UILabel!
    @IBOutlet weak var livenessLbl: UILabel!
    @IBOutlet weak var yawLbl: UILabel!
    @IBOutlet weak var rollLbl: UILabel!
    @IBOutlet weak var pitchLbl: UILabel!
    
    @IBOutlet weak var similarityScoreLbl: UILabel!
    @IBOutlet weak var similarityView: CircularProgressView!
    
    
    var session = AVCaptureSession()
    var recognized = false

    var cameraLens_val:AVCaptureDevice.Position = .front
    var livenessThreshold = Float(0)
    var matchingThreshold = Float(0)

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: ViewController.CORE_DATA_NAME)
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        cameraView.translatesAutoresizingMaskIntoConstraints = true
        cameraView.frame = view.bounds
        
        faceView.translatesAutoresizingMaskIntoConstraints = true
        faceView.frame = view.bounds

        resultView.translatesAutoresizingMaskIntoConstraints = true
        resultView.frame = view.bounds

        let defaults = UserDefaults.standard
        cameraLens_val = .front
        livenessThreshold = defaults.float(forKey: "liveness_threshold")
        matchingThreshold = defaults.float(forKey: "matching_threshold")

        
        self.startCamera(cameraLens: AVCaptureDevice.Position.front)
    }
    
    func startCamera(cameraLens: AVCaptureDevice.Position) {
        // Create an AVCaptureDevice for the camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraLens) else {
            print("Failed to get video device for camera position: \(cameraLens)")
            return
        }
        
        do {
            // Create an AVCaptureDeviceInput
            let input = try AVCaptureDeviceInput(device: videoDevice)
            
            // Configure the session with the input
            session.beginConfiguration()
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                print("Failed to add input device to session")
                session.commitConfiguration()
                return
            }
            
            // Create an AVCaptureVideoDataOutput
            let videoOutput = AVCaptureVideoDataOutput()
            
            // Set the video output's delegate and queue for processing video frames
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))
            
            // Add the video output to the session
            session.addOutput(videoOutput)
            
            // Configure preview layer
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = cameraView.bounds
            
            // Add preview layer to camera view
            cameraView.layer.addSublayer(previewLayer)
            
            // Start the session
            session.commitConfiguration()
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
        }
    }

    func stopCamera() {
        // Stop the session
        session.stopRunning()

        // Remove the preview layer from the view
        for layer in cameraView.layer.sublayers ?? [] {
            if layer is AVCaptureVideoPreviewLayer {
                layer.removeFromSuperlayer()
            }
        }
    }

    @IBAction func switchCamera_clicked(_ sender: Any) {
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else {
            return
        }
        
        let currentDevice = currentInput.device
        let newCameraPosition: AVCaptureDevice.Position = (currentDevice.position == .front) ? .back : .front
        cameraLens_val = newCameraPosition
        
        do {
            let newVideoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newCameraPosition)
            
            guard let newDevice = newVideoDevice else {
                print("Failed to get new video device for \(newCameraPosition)")
                return
            }
            
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            
            session.beginConfiguration()
            
            if let currentInput = session.inputs.first {
                session.removeInput(currentInput)
            }
            
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            } else {
                print("Failed to add new input device to session")
                session.commitConfiguration()
                return
            }
            
            session.commitConfiguration()
            
            print("Switched camera to \(newCameraPosition)")
        } catch {
            print("Error switching camera: \(error.localizedDescription)")
        }
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if(recognized == true) {
            return
        }
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let context = CIContext()
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let image = UIImage(cgImage: cgImage!)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)

        // Rotate and flip the image
        var capturedImage = image.rotate(radians: .pi/2)
        if(cameraLens_val == .front) {
            capturedImage = capturedImage.flipHorizontally()
        }
        
        let faceBoxes = FaceSDK.faceDetection(capturedImage)
       
        DispatchQueue.main.sync {
            self.faceView.setFrameSize(frameSize: capturedImage.size)
            self.faceView.setFaceBoxes(faceBoxes: faceBoxes)
        }

        if(faceBoxes.count > 0) {

            let faceBox = faceBoxes[0] as! FaceBox
            if(faceBox.liveness > livenessThreshold) {
                
                let templates = FaceSDK.templateExtraction(capturedImage, faceBox: faceBox)
                
                var maxSimilarity = Float(0)
                var maxSimilarityName = ""
                var maxSimilarityFace: Data? = nil
                
                let context = self.persistentContainer.viewContext
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ViewController.ENTITIES_NAME)

                do {
                    let persons = try context.fetch(fetchRequest) as! [NSManagedObject]
                    for person in persons {
                        
                        let personTemplates = person.value(forKey: ViewController.ATTRIBUTE_TEMPLATES) as! Data
                        
                        let similarity = FaceSDK.similarityCalculation(templates, templates2: personTemplates)
                        
                        if(maxSimilarity < similarity) {
                            maxSimilarity = similarity
                            maxSimilarityName = person.value(forKey: ViewController.ATTRIBUTE_NAME) as! String
                            maxSimilarityFace = person.value(forKey: ViewController.ATTRIBUTE_FACE) as? Data
                        }
                    }
                } catch {
                    print("Failed fetching: \(error)")
                }
                
                if(maxSimilarity > matchingThreshold) {
                    let enrolledFaceImage = UIImage(data: maxSimilarityFace!)
                    let identifiedFaceImage = capturedImage.cropFace(faceBox: faceBox)
                    
                    recognized = true
                    
                    DispatchQueue.main.sync {
                        self.enrolledImage.image = enrolledFaceImage
                        self.identifiedImage.image = identifiedFaceImage
                        enrolledNameLbl.text = maxSimilarityName
                        similarityScoreLbl.text = String(format: "%.01f", maxSimilarity*100) + "%"
                        
                        similarityView.setProgressColor = UIColor(named: "clr_main_button_bg1")!
                        similarityView.setTrackColor = UIColor(named: "clr_main_button_bg3")!
                        similarityView.setProgressWithAnimation(duration: 0.4, value: maxSimilarity)
                        
                        self.livenessLbl.text = String(format: "%.04f", faceBox.liveness)
                        self.yawLbl.text = String(format: "%.04f", faceBox.yaw)
                        self.rollLbl.text = String(format: "%.04f", faceBox.roll)
                        self.pitchLbl.text = String(format: "%.04f", faceBox.pitch)
                        
                        enrolledView.layer.cornerRadius = enrolledView.frame.size.width/2
                        enrolledImage.layer.cornerRadius = enrolledImage.frame.size.width/2
                        identifiedView.layer.cornerRadius = identifiedView.frame.size.width/2
                        identifiedImage.layer.cornerRadius = identifiedImage.frame.size.width/2
                        self.resultView.showView(isHidden_: true)
                    }
                }
            }
        }
    }
    
    @IBAction func done_clicked(_ sender: Any) {
        self.resultView.showView(isHidden_: false)
        recognized = false
    }
    
}

extension UIView {
    
    func showView(isHidden_: Bool) {
        
        if isHidden_ {
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 1.0
            }, completion: {_ in
                self.isHidden = false
            })
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 0.0
            }, completion: {_ in
                self.isHidden = true
            })
        }
    }
}

