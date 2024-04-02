

import UIKit

protocol PersonViewCellDelegate: AnyObject {
    func didPersonDelete(_ cell: UITableViewCell)
    func didNameChanged(_ cell: UITableViewCell)
}

class PersonViewCell: UITableViewCell, UITextViewDelegate {
    
    @IBOutlet weak var faceImage: UIImageView!
    @IBOutlet weak var txtName: UITextView!
    
    weak var delegate: PersonViewCellDelegate?
    var indexPath: IndexPath?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        txtName.isEditable = false
        txtName.autocorrectionType = .no
        txtName.isSelectable = false
        txtName.delegate = self
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func delete_clicked(_ sender: Any) {
        delegate?.didPersonDelete(self)
    }
    
    @IBAction func edit_clicked(_ sender: Any) {
        txtName.isEditable = true
        txtName.becomeFirstResponder()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            delegate?.didNameChanged(self)
            txtName.isEditable = false
            txtName.isSelectable = false
            return false
        }
        return true
    }
}
