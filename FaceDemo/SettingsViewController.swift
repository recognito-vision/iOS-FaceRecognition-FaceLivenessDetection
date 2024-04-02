import UIKit
import AVFoundation
import CoreData

class SettingsViewController: UIViewController{
    
    static let LIVENESS_THRESHOLD_DEFAULT = Float(0.7)
    static let MATCHING_THRESHOLD_DEFAULT = Float(0.8)
    
    
    @IBOutlet weak var livenessThresholdLbl: UILabel!
    @IBOutlet weak var matchingThresholdLbl: UILabel!
    
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
        
        let defaults = UserDefaults.standard
        
        let livenessThreshold = defaults.float(forKey: "liveness_threshold")
        livenessThresholdLbl.text = String(livenessThreshold)

        let matchingThreshold = defaults.float(forKey: "matching_threshold")
        matchingThresholdLbl.text = String(matchingThreshold)
    }
    
    static func setDefaultSettings() {
        let defaults = UserDefaults.standard
        let defaultChanged = defaults.bool(forKey: "default_changed")
        if(defaultChanged == false) {
            defaults.set(true, forKey: "default_changed")
            
            defaults.set(SettingsViewController.LIVENESS_THRESHOLD_DEFAULT, forKey: "liveness_threshold")
            defaults.set(SettingsViewController.MATCHING_THRESHOLD_DEFAULT, forKey: "matching_threshold")
        }
    }
        
    @IBAction func done_clicked(_ sender: Any) {
        if let vc = self.presentingViewController as? ViewController {
            self.dismiss(animated: true, completion: {
                vc.personView.reloadData()
            })
        }
    }
    
    @IBAction func livenessThreshold_clicked(_ sender: Any) {
        
        let title = "Liveness threshold"
        let alertController = UIAlertController(title: title, message: "Please input a number between 0 and 1.", preferredStyle: .alert)

        let minimum = Float(0)
        let maximum = Float(1)
        alertController.addTextField { (textField) in
            textField.keyboardType = .decimalPad
            
            let defaults = UserDefaults.standard
            textField.text = String(defaults.float(forKey: "liveness_threshold"))
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        let submitAction = UIAlertAction(title: "Ok", style: .default) { (action) in
            
            var hasError = false
            var errorStr = ""
            let defaults = UserDefaults.standard
            
            if let numberString = alertController.textFields?.first?.text, let number = Float(numberString) {
                if(number < Float(minimum) || number > Float(maximum)) {
                    hasError = true
                    errorStr = "Setting failed!"
                } else {
                    self.livenessThresholdLbl.text = String(number)
                    defaults.set(number, forKey: "liveness_threshold")
                }
            } else {
                hasError = true
                errorStr = "Setting failed!"
            }
            
            if(hasError) {
                let errorNotification = UIAlertController(title: "Error", message: errorStr, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                errorNotification.addAction(okAction)
                self.present(errorNotification, animated: true, completion: nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    errorNotification.dismiss(animated: true, completion: nil)
                }
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(submitAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func matchingThreshold_clicked(_ sender: Any) {
        
        let title = "Matching threshold"
        let alertController = UIAlertController(title: title, message: "Please input a number between 0 and 1.", preferredStyle: .alert)

        let minimum = Float(0)
        let maximum = Float(1)
        alertController.addTextField { (textField) in
            textField.keyboardType = .decimalPad
            
            let defaults = UserDefaults.standard
            textField.text = String(defaults.float(forKey: "matching_threshold"))
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        let submitAction = UIAlertAction(title: "Ok", style: .default) { (action) in
            
            var hasError = false
            var errorStr = ""
            let defaults = UserDefaults.standard
            
            if let numberString = alertController.textFields?.first?.text, let number = Float(numberString) {
                if(number < Float(minimum) || number > Float(maximum)) {
                    hasError = true
                    errorStr = "Setting failed!"
                } else {
                    self.matchingThresholdLbl.text = String(number)
                    defaults.set(number, forKey: "matching_threshold")
                }
            } else {
                hasError = true
                errorStr = "Setting failed!"
            }
            
            if(hasError) {
                let errorNotification = UIAlertController(title: "Error", message: errorStr, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                errorNotification.addAction(okAction)
                self.present(errorNotification, animated: true, completion: nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    errorNotification.dismiss(animated: true, completion: nil)
                }
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(submitAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    
    @IBAction func restore_settings_clicked(_ sender: Any) {
        let alertController = UIAlertController(title: "Confirm", message: "Are you sure you want to reset all settings?", preferredStyle: .alert)
        
        let yesAction = UIAlertAction(title: "Yes", style: .default) { _ in
            // Code to execute when "Yes" is tapped
            let defaults = UserDefaults.standard
            defaults.set(false, forKey: "default_changed")
            
            SettingsViewController.setDefaultSettings()
            self.viewDidLoad()
            showToast(message: "Reset to default settings")
        }
        let noAction = UIAlertAction(title: "No", style: .cancel) { _ in
            // Code to execute when "No" is tapped
            print("User tapped No")
        }
        
        alertController.addAction(yesAction)
        alertController.addAction(noAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    
    @IBAction func clear_all_person_clicked(_ sender: Any) {
        
        let alertController = UIAlertController(title: "Confirm", message: "Are you sure you want to remove all users?", preferredStyle: .alert)
        
        let yesAction = UIAlertAction(title: "Yes", style: .default) { _ in
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ViewController.ENTITIES_NAME)

            do {
                let persons = try context.fetch(fetchRequest) as! [NSManagedObject]
                for person in persons {
                    context.delete(person)
                }
                try context.save()
            } catch {
                print("Failed fetching: \(error)")
            }
            
            showToast(message: "Removed all users")
        }
        let noAction = UIAlertAction(title: "No", style: .cancel) { _ in
            // Code to execute when "No" is tapped
            print("User tapped No")
        }
        
        alertController.addAction(yesAction)
        alertController.addAction(noAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func gotoSite(_ sender: Any) {
        let telegramURL = URL(string: "https://recognito.vision")!
        UIApplication.shared.open(telegramURL, options: [:], completionHandler: nil)
    }
}

