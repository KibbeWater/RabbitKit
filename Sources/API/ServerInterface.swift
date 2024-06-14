//
//  ServerInterface.swift
//  
//
//  Created by Linus Rönnbäck Larsson on 2024-06-03.
//

import Foundation

enum ResponsePacketType: String, Codable {
    case authenticate = "logon"
    case text = "message"
    case ptt
    case audio
    case register
    case long
}

struct BasicResponsePacket: Codable {
    let type: ResponsePacketType
}

struct ResponsePacket<T: Codable>: Codable {
    let type: ResponsePacketType
    let data: T
    
    init(type: ResponsePacketType, data: T) {
        self.type = type
        self.data = data
    }
}

protocol ResponseType: Codable {}

struct ResponseRegister: ResponseType {
    let imei: String
    let accountKey: String
    let userName: String
    let userId: String
    let actualUserId: String
}

struct ResponseLong: ResponseType {
    let text: String
    let images: [String]
}

public struct ResponseAudio: ResponseType {
    public let text: TextData?
    public let audio: Data
    
    public init(from decoder: any Decoder) throws {
        let jsonDecoder = JSONDecoder()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let b64Audio = try container.decode(String.self, forKey: .audio)
        self.audio = Data(base64Encoded: b64Audio) ?? Data()
        
        var jsonText = try container.decode(String.self, forKey: .text)
        jsonText = jsonText.replacingOccurrences(of: "\\", with: "")
        self.text = try? jsonDecoder.decode(TextData.self, from: jsonText.data(using: .utf8) ?? Data())
    }
    
    public struct TextData: Codable {
        public let lang: String
        public let chars: [String]
        public let charStart: [Int]
        public let charDuration: [Int]
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<ResponseAudio.TextData.CodingKeys> = try decoder.container(keyedBy: ResponseAudio.TextData.CodingKeys.self)
            self.lang = try container.decode(String.self, forKey: .lang)
            self.chars = try container.decode([String].self, forKey: .chars)
            self.charStart = try container.decode([Int].self, forKey: .charStart)
            self.charDuration = try container.decode([Int].self, forKey: .charDuration)
        }
        
        enum CodingKeys: String, CodingKey {
            case lang = "language"
            case chars
            case charStart = "char_start_times_ms"
            case charDuration = "char_durations_ms"
        }
    }
}
