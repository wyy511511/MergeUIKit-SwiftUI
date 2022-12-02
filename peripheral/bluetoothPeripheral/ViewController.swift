//
//  ViewController.swift
//  bluetoothPeripheral


import UIKit
import CoreBluetooth

let serviceUUID = CBUUID(string: "5FBDB555-14E7-4CC6-A612-6821474550DD")
let writeUUID = CBUUID(string: "7B28942C-9604-4AF6-B84E-274F12605F0C")
let readUUID = CBUUID(string: "7B28942C-9604-4AF6-B84E-274F12605F0C")
let notifyUUID = CBUUID(string: "CE807494-7CEA-49D1-A230-F2EAB5120985")

class ViewController: UIViewController {
    
    @IBOutlet weak var writeLabel: UILabel!
    @IBOutlet weak var readLabel: UILabel!
    @IBOutlet weak var notifyLabel: UILabel!
    
    var peripheralManager: CBPeripheralManager!
    var writeCharacteristic: CBMutableCharacteristic!
    var notifyCharacteristic: CBMutableCharacteristic!
    var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //创建外设管理器--立即调用peripheralManagerDidUpdateState
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
}

extension ViewController: CBPeripheralManagerDelegate{
    //确保本外设支持蓝牙低能耗（BLE）并开启时才继续操作
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state{
        case .unknown:
            print("未知状态")
        case .resetting:
            print("重置中")
        case .unsupported:
            print("不支持低能耗蓝牙（BLE）")
        case .unauthorized:
            print("未授权")
        case .poweredOff:
            print("蓝牙未开启")
        case .poweredOn:
            print("蓝牙开启")
            //创建Service（服务）和Characteristics（特征）
            
            //primary表明是这个外设的主要服务，例：
            //主要服务-从心率监测仪获得的心率数据；次要服务-从心率监测仪获得的电量数据
            let service = CBMutableService(type: serviceUUID, primary: true)
            
            //properties和permissions可多个（写成数组）
            //value不写死以便以后可动态修改
            writeCharacteristic = CBMutableCharacteristic(type: writeUUID, properties: .write, value: nil, permissions: .writeable)
            let readCharacteristic = CBMutableCharacteristic(type: readUUID, properties: .read, value: nil, permissions: .readable)
            notifyCharacteristic = CBMutableCharacteristic(type: notifyUUID, properties: .notify, value: nil, permissions: .readable)
            
            //把特征加到服务里去
            service.characteristics = [writeCharacteristic,readCharacteristic,notifyCharacteristic]
            
            //把服务加到外设管理器中去--立即调用didAdd service
            peripheralManager.add(service)
            
            //开始广播某服务--立即调用DidStartAdvertising
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[serviceUUID]])
            
        @unknown default:
            print("来自未来的错误")
        }
    }
    //当在外设管理器中添加服务时
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error{
            print("无法添加服务，原因是：\(error.localizedDescription)")
        }
    }
    //开始广播某服务后
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error{
            print("无法开始广播，原因是：\(error.localizedDescription)")
        }
    }
    
    //⬇️⬇️一旦开始广播，此外设就能被中心设备发现，并被连接--之后就等待中心设备发号施令，我这边负责接受并反馈就行了⬇️⬇️
    
    
    //当中心设备发送(对一个或多个特征值的)写入请求时
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        let request = requests[0]
        if request.characteristic.properties.contains(.write){
            //给当前请求的特征改值
            writeCharacteristic.value = request.value
            //显示到视图
            writeLabel.text = String(data: request.value!, encoding: .utf8)
            //给中心设备反馈，以便中心设备可以触发一些delegate方法
            peripheral.respond(to: request, withResult: .success)
        }else{
            peripheral.respond(to: request, withResult: .writeNotPermitted)
        }
    }
    
    //当中心设备发送读取(某个特征的值)请求时
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.properties.contains(.read){
            //给request下的value赋当前请求特征的值，然后随着respond带到中心设备去
            //request.value = request.characteristic.value
            //这里用文本框中的数据模拟某个特征的值
            request.value = readLabel.text!.data(using: .utf8)
            peripheral.respond(to: request, withResult: .success)
        }else{
            peripheral.respond(to: request, withResult: .readNotPermitted)
        }
    }
    
    //当中心设备订阅了某个特征值时
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        updateNotifyValue()
    }
    //当中心设备取消订阅某个特征值时
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        timer?.invalidate()
    }
    //传输队列有了剩余空间时
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        updateNotifyValue()
    }
    

    
    func updateNotifyValue(){
        //用计时器模拟外设数据的实时变动
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年MM月dd日 HH时mm分ss秒"
            let dateStr = dateFormatter.string(from: Date())
            
            self.notifyLabel.text = dateStr//也同时实时显示到本外设上来，方便演示
            
            //更新特征值+给一个或多个(第三参数指定为nil)订阅了这个特征的中心设备发送实时数据
            //返回bool，true->发送成功，false->传输队列已满
            //如果待会又有了空间，则调用peripheralManagerIsReady，可在里面再次发送数据
            self.peripheralManager.updateValue(dateStr.data(using: .utf8)!, for: self.notifyCharacteristic, onSubscribedCentrals: nil)
            
        }
    }
    
}
