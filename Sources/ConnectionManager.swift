//
//  ConnectionManager.swift
//  
//
//  Created by Linus Rönnbäck Larsson on 2024-06-03.
//

import Foundation
import UIKit

class ConnectionManager : NSObject, URLSessionWebSocketDelegate {
    var onData: (ResponsePacketType, Data) -> Void
    var onConnect: () -> Void
    var onClose: () -> Void
    var onError: () -> Void
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    
    private var wsURL: URL
    
    init(_ url: URL, onData: @escaping (ResponsePacketType, Data) -> Void, onConnect: @escaping () -> Void, onClose: @escaping () -> Void, onError: @escaping () -> Void, webSocketTask: URLSessionWebSocketTask? = nil) {
        self.onData = onData
        self.onConnect = onConnect
        self.onClose = onClose
        self.onError = onError
        self.wsURL = url
        super.init()
        
        addObservers()
        connect()
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        if webSocketTask?.state != .running {
            connect()
        }
    }
    
    public func connect() {
        webSocketTask?.cancel(with: .goingAway, reason: "Restaring connection".data(using: .utf8))
        print("Connecting")
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval.infinity
        configuration.timeoutIntervalForResource = TimeInterval.infinity
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session?.webSocketTask(with: wsURL)
        webSocketTask?.resume()
        receiveMessage()
    }
    
    public func getStatus() -> URLSessionTask.State? {
        return webSocketTask?.state
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { result in
            switch result {
            case .failure(let error):
                self.onError()
                if error.localizedDescription.contains("Socket is not connected") {
                    print("Reconnecting")
                    self.connect()
                }
                print(error.localizedDescription)
            case .success(let message):
                self.receiveMessage()
                switch message {
                case .string(let jsonData):
                    let data = jsonData.data(using: .utf8) ?? Data()
                    let jsonDecoder = JSONDecoder()
                    guard let decodedPacket = try? jsonDecoder.decode(BasicResponsePacket.self, from: data) else { return print("Failed to parse packet \(String(describing: String(data: data, encoding: .utf8)))") }
                    
                    DispatchQueue.main.async {
                        self.onData(decodedPacket.type, data)
                    }
                case .data(_):
                    // Handle binary data
                    print("Received binary data")
                    break
                @unknown default:
                    print("Unknown def")
                    break
                }
            }
        }
    }
    
    func sendData(_ data: Data) {
        webSocketTask?.send(.data(data)) { error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    func sendMessage<T: Codable>(_ message: RequestPacket<T>) {
        let jsonEncoder = JSONEncoder()
        guard let data = try? jsonEncoder.encode(message) else { return }
        webSocketTask?.send(
            .string(
                String(data: data, encoding: .utf8)!
            )
        ) { error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // Handle connection established
        onConnect()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        // Handle connection closed
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "No reason"
        print("WebSocket connection closed: \(reasonString)")
        onClose()
    }
}
