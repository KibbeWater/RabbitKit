//
//  BaseEvent.swift
//
//
//  Created by Linus Rönnbäck Larsson on 2024-06-03.
//

import Foundation

protocol Event: Codable {
    var type: ResponsePacketType { get }
}
