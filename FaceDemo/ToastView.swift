
import UIKit

class ToastView: UIView {
    private let messageLabel: UILabel = UILabel()

    init(message: String) {
        super.init(frame: .zero)
        configureUI()
        setMessage(message)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        backgroundColor = UIColor(named: "clr_toast_bg")
        layer.cornerRadius = 25
        clipsToBounds = true

        messageLabel.textColor = UIColor(named: "txt_clr_third")
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        addSubview(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    private func setMessage(_ message: String) {
        messageLabel.text = message
    }
}

func showToast(message: String, duration: TimeInterval = 2.0) {
    let toastView = ToastView(message: message)
    if let window = UIApplication.shared.windows.first {
        window.addSubview(toastView)
        toastView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: window.bottomAnchor, constant: -50),
            toastView.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 32),
            toastView.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -32),
            toastView.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])

        UIView.animate(withDuration: 0.2, delay: duration, options: .curveEaseInOut) {
            toastView.alpha = 0
        } completion: { _ in
            toastView.removeFromSuperview()
        }
    }
}
