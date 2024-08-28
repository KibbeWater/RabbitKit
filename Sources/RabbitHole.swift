//
//  RabbitHole.swift
//
//
//  Created by Linus Rönnbäck Larsson on 2024-06-03.
//

import Foundation
import SwiftUI

public struct ChatMessage: Identifiable {
    public var id: UUID
    
    init(author: AuthorType, type: DataType, data: Data) {
        self.id = UUID()
        self.author = author
        self.type = type
        self.data = data
        self.date = Date.now
    }
    
    public let author: AuthorType
    public let type: DataType
    public let data: Data
    public let date: Date
    
    public enum AuthorType {
        case rabbit
        case system
        case user
    }
    
    public enum DataType {
        case image
        case audio
        case text
    }
}

public enum WSStatus {
    case connecting
    case open
    case closed
}

public class RabbitHole: ObservableObject {
    @ObservedObject public var rabbitPlayer = RabbitPlayer()
    var connectionManager: ConnectionManager?
    var keychain = KeychainService()
    
    @Published public var messages = [ChatMessage]()
    
    @Published public var isAuthenticated = false
    @Published public var isAuthenticating = false
    @Published public var canAuthenticate = false
    @Published public var isMeetingActive = false
    
    @Published public var hasCredentials = false
    
    @Published public var lastImages = [String]()
    
    @Published public var wsStatus: WSStatus = .closed
    
    public func sendText(_ message: String) {
        self.connectionManager?.sendMessage(RequestPacket(
            type: .text,
            data: message
        ))
    }
    
    public func sendPTT(_ isActive: Bool, image: Data? = nil) {
        var _image: String? = nil
        if let _img = image {
            _image = "data:image/jpeg;base64," + _img.base64EncodedString()
        }
        
        self.connectionManager?.sendMessage(RequestPacket(
            type: .ptt,
            data: RequestPTT(
                active: isActive,
                image: _image
            )
        ))
    }
    
    public func sendAudio(_ audioData: Data) {
        self.connectionManager?.sendMessage(RequestPacket(
            type: .audio,
            data: "data:audio/wav;base64," + audioData.base64EncodedString()
        ))
    }
    
    public func register(_ url: URL) {
        self.connectionManager?.sendMessage(RequestPacket(
            type: .register,
            data: url.absoluteString
        ))
    }
    
    public func stopMeeting() {
        guard isMeetingActive && wsStatus == .open else { return }
        self.connectionManager?.sendMessage(RequestPacket(
            type: .meeting,
            data: false
        ))
    }
    
    func startLogin(imei: String, accountKey: String) {
        DispatchQueue.main.async {
            self.canAuthenticate = false
            self.isAuthenticating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            self.isAuthenticating = false
        }
        
        self.connectionManager!.sendMessage(
            RequestPacket(
                type: .authenticate,
                data: RequestAuth(
                    imei: imei,
                    accountKey: accountKey
                )
            )
        )
    }
    
    public func signIn(imei: String, accountKey: String) {
        self.keychain.save(imei, forKey: "imei")
        self.keychain.save(accountKey, forKey: "accountKey")
        
        startLogin(imei: imei, accountKey: accountKey)
    }
    
    public func resetCredentials() {
        self.keychain.delete(forKey: "imei")
        self.keychain.delete(forKey: "accountKey")
        hasCredentials = false
    }
    
    public func getCredentials() -> (imei: String, accountKey: String)? {
        guard hasCredentials else { return nil }
        let imei = self.keychain.read(forKey: "imei")
        let accountKey = self.keychain.read(forKey: "accountKey")
        if imei?.isEmpty == true || accountKey?.isEmpty == true { return nil }
        return (imei!, accountKey!)
    }
    
    func internalHasCredentials() {
        guard let imei = self.keychain.read(forKey: "imei"),
              let accountKey = self.keychain.read(forKey: "accountKey") else {
            hasCredentials = false
            return
        }
        hasCredentials = imei != "" && accountKey != ""
    }
    
    func addMessage(_ message: ChatMessage) {
        DispatchQueue.main.async {
            self.messages.append(message)
        }
    }
    
    public func reconnect(_ newUrl: URL? = nil) {
        self.wsStatus = .connecting
        internalHasCredentials()
        if let url = newUrl {
            self.connectionManager?.connect(url)
        } else {
            self.connectionManager?.connect()
        }
    }
    
    public func refreshStatus() {
        if let state = connectionManager?.getStatus() {
            switch state {
            case .completed, .canceling, .suspended:
                wsStatus = .closed
            default:
                break
            }
        }
    }
    
    public init(_ url: URL, autoConnect: Bool = true) {
        print("Initing")
        internalHasCredentials()
        self.wsStatus = .connecting
        self.connectionManager = ConnectionManager(url, onData: { type, data in
            DispatchQueue.main.async {
                self.wsStatus = .open
            }
            self.onData(type: type, data: data)
        }, onConnect: {
            DispatchQueue.main.async {
                self.wsStatus = .open
                self.isMeetingActive = false
            }
            print("Connected to Rabbithole")
            self.addMessage(ChatMessage(
                    author: .system,
                    type: .text,
                    data: "Connected to Rabbithole".data(using: .utf8)!
            ))
            
            DispatchQueue.main.async {
                self.canAuthenticate = true
            }
            
            guard let imei = self.keychain.read(forKey: "imei"),
                  let accountKey = self.keychain.read(forKey: "accountKey") else {
                print("Unable to read imei or accountKey")
                return
            }
            
            if autoConnect {
                self.startLogin(imei: imei, accountKey: accountKey)
            }
        }, onClose: {
            DispatchQueue.main.async {
                self.wsStatus = .closed
            }
            print("Closed")
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.canAuthenticate = false
                self.isAuthenticating = false
            }
        }, onError: {
            print("Errored")
            DispatchQueue.main.async {
                self.wsStatus = .closed
            }
            self.addMessage(ChatMessage(
                author: .system,
                type: .text,
                data: "Unexpected error occured".data(using: .utf8)!
            ))
        })
    }
    
    func onData(type: ResponsePacketType, data: Data) {
        let jsonDecoder = JSONDecoder()
        switch type {
        case .text:
            guard let msgResponse = try? jsonDecoder.decode(ResponsePacket<String>.self, from: data) else { return }
            addMessage(ChatMessage(
                author: .rabbit,
                type: .text,
                data: msgResponse.data.data(using: .utf8)!
            ))
        case .audio:
            guard let audioResponse = try? jsonDecoder.decode(ResponsePacket<ResponseAudio>.self, from: data) else { return }
            rabbitPlayer.speak(audioResponse.data)
        case .authenticate:
            guard let authResponse = try? jsonDecoder.decode(ResponsePacket<String>.self, from: data) else { return }
            
            print(authResponse.data)
            if authResponse.data == "failure" {
                isAuthenticating = false
                resetCredentials()
                return
            }
            
            withAnimation {
                canAuthenticate = false
                isAuthenticating = false
                isAuthenticated = true
            }
            
            addMessage(ChatMessage(
                author: .system,
                type: .text,
                data: "Authenticated Successfully".data(using: .utf8)!
            ))
        case .register:
            guard let authResponse = try? jsonDecoder.decode(ResponsePacket<ResponseRegister>.self, from: data) else { return }
            
            keychain.save(authResponse.data.imei, forKey: "imei")
            keychain.save(authResponse.data.accountKey, forKey: "accountKey")
            
            connectionManager!.sendMessage(
                RequestPacket(
                    type: .authenticate,
                    data: RequestAuth(
                        imei: authResponse.data.imei,
                        accountKey: authResponse.data.accountKey
                    )
                )
            )
            
            addMessage(ChatMessage(
                author: .system,
                type: .text,
                data: "Registered".data(using: .utf8)!
            ))
        case .ptt:
            guard let pttResponse = try? jsonDecoder.decode(ResponsePacket<String>.self, from: data) else { return }
            addMessage(ChatMessage(
                author: .user,
                type: .audio,
                data: pttResponse.data.data(using: .utf8) ?? Data()
            ))
        case .long:
            guard let longResponse = try? jsonDecoder.decode(ResponsePacket<ResponseLong>.self, from: data) else { return }
            lastImages = longResponse.data.images
            addMessage(ChatMessage(
                author: .rabbit,
                type: .image,
                data: longResponse.data.images
                    .joined(separator: "\n")
                    .data(using: .utf8) ?? Data()
                )
            )
        case .meeting:
            guard let meetingResponse = try? jsonDecoder.decode(ResponsePacket<Bool>.self, from: data) else { return }
            DispatchQueue.main.async {
                self.isMeetingActive = meetingResponse.data
            }
        }
    }
}
