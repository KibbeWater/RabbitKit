//
//  MessageEvent.swift
//
//
//  Created by Linus Rönnbäck Larsson on 2024-06-03.
//

import Foundation

struct MessageEvent: Event {
    var type: ResponsePacketType
    let data: ResponsePacket<String>
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(ResponsePacketType.self, forKey: .type)
        self.data = try container.decode(ResponsePacket<String>.self, forKey: .data)
    }
}
