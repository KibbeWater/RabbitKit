//
//  ClientInterface.swift
//  
//
//  Created by Linus Rönnbäck Larsson on 2024-06-03.
//

import Foundation

enum RequestPacketType: String, Codable {
    case authenticate = "logon"
    case text = "message"
    case ptt
    case audio
    case register
}

struct BasicRequestPacket: Codable {
    let type: RequestPacketType
}

struct RequestPacket<T: Codable>: Codable {
    let type: RequestPacketType
    let data: T
    
    init(type: RequestPacketType, data: T) {
        self.type = type
        self.data = data
    }
}

protocol RequestType: Codable {}

struct RequestAuth: RequestType {
    let imei: String
    let accountKey: String
}

struct RequestPTT: RequestType {
    let active: Bool
    let image: String?
}
