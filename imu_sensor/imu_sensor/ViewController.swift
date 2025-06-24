import UIKit
import CoreMotion
import Network

class ViewController: UIViewController {

    let motionManager = CMMotionManager()
    let poseLabel = UILabel()
    var connection: NWConnection?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUDPConnection()

        // 設定 Label
        poseLabel.frame = CGRect(x: 20, y: 100, width: view.frame.width - 40, height: 100)
        poseLabel.numberOfLines = 0
        poseLabel.textAlignment = .center
        poseLabel.font = UIFont.systemFont(ofSize: 20)
        poseLabel.text = "Yaw: 0°\nPitch: 0°\nRoll: 0°"
        view.addSubview(poseLabel)

        // 設定 Reset 按鈕（現在只是 UI 提示，不改變角度資料）
        let resetButton = UIButton(type: .system)
        resetButton.frame = CGRect(x: (view.frame.width - 200) / 2, y: 220, width: 200, height: 50)
        resetButton.setTitle("重新定位 (Reset)", for: .normal)
        resetButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        resetButton.addTarget(self, action: #selector(resetPose), for: .touchUpInside)
        view.addSubview(resetButton)

        // 設定更新頻率
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0  // 60 Hz

        motionManager.startDeviceMotionUpdates(to: .main) { (motion, error) in
            guard let motion = motion else { return }

            //取得絕對姿態角度（單位轉成 degrees）
            let roll = -Float(motion.attitude.roll * 180 / .pi)    // 加負號修正方向
            let pitch = Float(motion.attitude.pitch * 180 / .pi)
            let yaw = Float(motion.attitude.yaw * 180 / .pi)

            // 顯示目前姿態
            self.poseLabel.text = String(format: "Yaw: %.2f°\nPitch: %.2f°\nRoll: %.2f°",
                                         yaw, pitch, roll)

            print(String(format: "Yaw: %.2f°, Pitch: %.2f°, Roll: %.2f°",
                         yaw, pitch, roll))

            // 傳送原始角度給電腦
            self.sendHeadPose(yaw: yaw, pitch: pitch, roll: roll)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        motionManager.stopDeviceMotionUpdates()
    }

    @objc func resetPose() {
        // ❗現在不再影響傳輸資料，只做 UI 提示
        let alert = UIAlertController(title: "已重新定位", message: "角度基準未改變，已重設視覺參考點", preferredStyle: .alert)
        self.present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            alert.dismiss(animated: true)
        }
    }

    func setupUDPConnection() {
        let host = NWEndpoint.Host("192.168.31.188")  // 你的 PC IP
        let port = NWEndpoint.Port(rawValue: 45678)!
        connection = NWConnection(host: host, port: port, using: .udp)
        connection?.start(queue: .global())
    }

    func sendHeadPose(yaw: Float, pitch: Float, roll: Float) {
        let jsonString = String(format:
            "{\"yaw\":%.2f,\"pitch\":%.2f,\"roll\":%.2f}",
            yaw, pitch, roll)

        guard let data = jsonString.data(using: .utf8) else { return }

        connection?.send(content: data,
                         completion: .contentProcessed { error in
            if let error = error {
                print("UDP send error: \(error)")
            }
        })
    }
}
