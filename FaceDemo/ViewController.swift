import UIKit
import AVFoundation
import CoreData

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDataSource, UITableViewDelegate, PersonViewCellDelegate{
    
    static let CORE_DATA_NAME = "Model"
    static let ENTITIES_NAME = "Person"
    static let ATTRIBUTE_NAME = "name"
    static let ATTRIBUTE_FACE = "face"
    static let ATTRIBUTE_TEMPLATES = "templates"

    @IBOutlet weak var warningLbl: UILabel!
    
    @IBOutlet weak var enrollBtnView: UIView!
    @IBOutlet weak var identifyBtnView: UIView!
    
    @IBOutlet weak var personView: UITableView!
    
    
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
        var ret = SDK_LICENSE_KEY_ERROR.rawValue
        
        if let filePath = Bundle.main.path(forResource: "license", ofType: "txt") {
            do {
                let license = try String(contentsOfFile: filePath, encoding: .utf8)
                ret = FaceSDK.setActivation(license)
            } catch {
                print("Error reading file: \(error)")
            }
        } else {
            print("File not found")
        }
        
        if(ret == SDK_SUCCESS.rawValue) {
            ret = FaceSDK.initSDK()
        }
        
        if(ret != SDK_SUCCESS.rawValue) {
            warningLbl.isHidden = false
            
            if(ret == SDK_LICENSE_KEY_ERROR.rawValue) {
                warningLbl.text = "License key error!"
            } else if(ret == SDK_LICENSE_APPID_ERROR.rawValue) {
                warningLbl.text = "App ID error!"
            } else if(ret == SDK_LICENSE_EXPIRED.rawValue) {
                warningLbl.text = "License key expired!"
            } else if(ret == SDK_NO_ACTIVATED.rawValue) {
                warningLbl.text = "Activation failed!"
            } else if(ret == SDK_INIT_ERROR.rawValue) {
                warningLbl.text = "Engine init error!"
            }
        }
        
        SettingsViewController.setDefaultSettings()
        
        personView.delegate = self
        personView.dataSource = self
        personView.separatorStyle = .none
        personView.reloadData()
        
    }
    
    
    @IBAction func enroll_touch_down(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.enrollBtnView.backgroundColor = UIColor(named: "clr_main_button_bg2") // Change to desired color
        }
    }
    
    @IBAction func enroll_touch_cancel(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.enrollBtnView.backgroundColor = UIColor(named: "clr_main_button_bg1") // Change to desired color
        }
    }
    
    @IBAction func enroll_clicked(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.enrollBtnView.backgroundColor = UIColor(named: "clr_main_button_bg1") // Change to desired color
        }

        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    
    @IBAction func identify_touch_down(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.identifyBtnView.backgroundColor = UIColor(named: "clr_main_button_bg2") // Change to desired color
        }
    }
    
    @IBAction func identify_touch_up(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.identifyBtnView.backgroundColor = UIColor(named: "clr_main_button_bg1") // Change to desired color
        }
    }
    
    @IBAction func identify_clicked(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.identifyBtnView.backgroundColor = UIColor(named: "clr_main_button_bg1") // Change to desired color
        }
        
        performSegue(withIdentifier: "camera", sender: self)
    }
     
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    
        dismiss(animated: true, completion: nil)

        guard let image = info[.originalImage] as? UIImage else {
            return
        }

        let fixed_image = image.fixOrientation()
        let faceBoxes = FaceSDK.faceDetection(fixed_image)
        if(faceBoxes.count == 0) {
            showToast(message: "No face!")
            return
        } else if(faceBoxes.count > 1) {
            showToast(message: "Multiple faces detected!")
        }
        
        for faceBox in (faceBoxes as NSArray as! [FaceBox]) {
            
            let templates = FaceSDK.templateExtraction(fixed_image, faceBox: faceBox)
            if(templates.isEmpty) {
                continue
            }
            
            let faceImage = fixed_image.cropFace(faceBox: faceBox)
            
            let context = self.persistentContainer.viewContext
            let entity = NSEntityDescription.entity(forEntityName: ViewController.ENTITIES_NAME, in: context)!
            let user = NSManagedObject(entity: entity, insertInto: context)

            
            let currentDate = Date()
            let calendar = Calendar.current
            let year = calendar.component(.year, from: currentDate)
            let month = calendar.component(.month, from: currentDate)
            let dayOfMonth = calendar.component(.day, from: currentDate)
            let hour = calendar.component(.hour, from: currentDate)
            let minute = calendar.component(.minute, from: currentDate)
            let second = calendar.component(.second, from: currentDate)
            
            let name = "User " + String(year) + String(month) + String(dayOfMonth) + String(hour) + String(minute) + String(second)
            let face = faceImage!.jpegData(compressionQuality: CGFloat(1.0))
            
            user.setValue(name, forKey: ViewController.ATTRIBUTE_NAME)
            user.setValue(templates, forKey: ViewController.ATTRIBUTE_TEMPLATES)
            user.setValue(face, forKey: ViewController.ATTRIBUTE_FACE)
            
            do {
                try context.save()
            } catch let error as NSError {
                print("Could not save. \(error), \(error.userInfo)")
            }
        }
        
        personView.reloadData()
        showToast(message: "Registered user successfully")
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    // UITableViewDataSource methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of cells in the table view
        
        let context = self.persistentContainer.viewContext
        let count = try! context.count(for: NSFetchRequest(entityName: ViewController.ENTITIES_NAME))
        
        return count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Get the table view cell for the specified index path
        let cell = tableView.dequeueReusableCell(withIdentifier: "PersonCell", for: indexPath) as! PersonViewCell
        cell.delegate = self
        cell.indexPath = indexPath

        let context = self.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ViewController.ENTITIES_NAME)
        do {
            let persons = try context.fetch(fetchRequest) as! [NSManagedObject]
            var rowCount = 0
            for person in persons {
                if(rowCount == indexPath.row) {
                    cell.txtName.text = person.value(forKey: ViewController.ATTRIBUTE_NAME) as? String
                    cell.faceImage.image = UIImage(data: person.value(forKey: ViewController.ATTRIBUTE_FACE) as! Data)
                    
                    break
                }
                rowCount = rowCount + 1
            }
        } catch {
            print("Failed fetching: \(error)")
        }
        
        // Customize the cell
        return cell
    }

    // UITableViewDelegate methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Handle cell selection
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func didPersonDelete(_ cell: UITableViewCell) {
        let context = self.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ViewController.ENTITIES_NAME)
        let personCell = cell as! PersonViewCell

        let message = String(format: "Are you sure you want to remove <%@> user?", personCell.txtName.text)
        let alertController = UIAlertController(title: "Warning", message: message, preferredStyle: .alert)
        
        let yesAction = UIAlertAction(title: "Yes", style: .default) { _ in
            // Code to execute when "Yes" is tapped
            do {
                let persons = try context.fetch(fetchRequest) as! [NSManagedObject]
                var rowCount = 0
                for person in persons {
                    if(rowCount == personCell.indexPath?.row) {
                        context.delete(person)
                        try context.save()
                        break
                    }
                    rowCount = rowCount + 1
                }
            } catch {
                print("Failed fetching: \(error)")
            }
            
            self.personView.reloadData()
        }
        let noAction = UIAlertAction(title: "No", style: .cancel) { _ in
            // Code to execute when "No" is tapped
            print("User tapped No")
        }
        
        alertController.addAction(yesAction)
        alertController.addAction(noAction)
        
        if let viewController = UIApplication.shared.keyWindow?.rootViewController {
            viewController.present(alertController, animated: true, completion: nil)
        }
    }
    
    func checkUserExist(name: String) -> Bool {
        let context = self.persistentContainer.viewContext

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ViewController.ENTITIES_NAME)
        fetchRequest.predicate = NSPredicate(format: "\(ViewController.ATTRIBUTE_NAME) == %@", name)

        do {
            let existingUsers = try context.fetch(fetchRequest) as! [NSManagedObject]
            if existingUsers.isEmpty {
                return false
            } else {
                print("Name already exists in the database")
                return true
            }
        } catch {
            print("Failed fetching: \(error)")
        }
        return false
    }
    
    func didNameChanged(_ cell: UITableViewCell) {
        let context = self.persistentContainer.viewContext
        guard let personCell = cell as? PersonViewCell else {
            return
        }
        guard let updatedName = personCell.txtName.text else {
            return
        }
        let isExistName = checkUserExist(name: updatedName)
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ViewController.ENTITIES_NAME)
        do {
            let persons = try context.fetch(fetchRequest) as! [NSManagedObject]
            var rowCount = 0
            for person in persons {
                if(rowCount == personCell.indexPath?.row) {
                    if (updatedName == person.value(forKey: ViewController.ATTRIBUTE_NAME) as! String) {
                        break
                    }
                        
                    if !isExistName {
                        print("Updated user name")
                        person.setValue(updatedName, forKey: ViewController.ATTRIBUTE_NAME)
                        try context.save()
                    } else {
                        personCell.txtName.text = person.value(forKey: ViewController.ATTRIBUTE_NAME) as! String
                        showToast(message: "Failed! New name already exists in the user list")
                    }
                    
                    break
                }
                rowCount = rowCount + 1
            }
        } catch {
            print("Failed fetching: \(error)")
        }
        
        self.personView.reloadData()
    }
}

