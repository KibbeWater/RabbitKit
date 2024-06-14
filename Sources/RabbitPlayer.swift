//
//  RabbitPlayer.swift
//
//
//  Created by Linus Rönnbäck Larsson on 2024-06-03.
//

import Foundation
import AVFoundation
import CoreHaptics
import SwiftUI

public struct CurrentlyPlaying {
    public let audio: ResponseAudio
    public let time: Int
}

public class RabbitPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public var audioPlayer: AVAudioPlayer?
    private var audioQueue = [ResponseAudio]()
    
    private var engine: CHHapticEngine?
    
    @Published public var curPlaying: CurrentlyPlaying?
    
    @AppStorage("savedVol")
    private var savedVol: Double?
    
    func speak(_ data: ResponseAudio) {
        prepareHaptics()
        guard curPlaying != nil else {
            playWavData(data)
            return
        }
        audioQueue.insert(data, at: 0)
    }

    // Function to play wav data
    private func playWavData(_ data: ResponseAudio) {
        do {
            let hapticPattern = generatePattern(data)
            let player = hapticPattern != nil ? try? engine?.makePlayer(with: hapticPattern!) : nil
            
            audioPlayer = try AVAudioPlayer(data: data.audio)
            if let _vol = savedVol {
                audioPlayer?.setVolume(Float(_vol), fadeDuration: 0)
            }
            audioPlayer?.delegate = self
            
            audioPlayer?.prepareToPlay()
            try? player?.start(atTime: 0)
            audioPlayer?.play()
            
            DispatchQueue.main.async {
                self.curPlaying = CurrentlyPlaying(
                    audio: data,
                    time: Int(CACurrentMediaTime())
                )
            }
        } catch {
            // Handle the error if initialization fails
            print("Error initializing AVAudioPlayer: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.curPlaying = nil
            }
        }
    }
    
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the engine: \(error.localizedDescription)")
        }
    }
    
    func generatePattern(_ audio: ResponseAudio) -> CHHapticPattern? {
        // make sure that the device supports haptics
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        var events = [CHHapticEvent]()
        
        guard let text = audio.text else { return nil }
        
        guard text.chars.count > 0 else { return nil }

        // create one intense, sharp tap
        var swap: Bool = false
        for i in 0...text.chars.count-1 {
            let startValue = text.charStart[i]
            let char = text.chars[i]
            
            if char == " " || char == "," || char == "." {
                swap = true
                continue
            }
            
            if !swap {
                continue
            }
            swap = false
            
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: TimeInterval(Double(startValue) / 1000))
            events.append(event)
        }
        
        print("Generated \(events.count) events")

        // convert those events into a pattern and play it immediately
        return try? CHHapticPattern(events: events, parameters: [])
        
        /*do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play pattern: \(error.localizedDescription).")
        }*/
    }
    
    // Example delegate method to handle playback completion
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let nextItem = audioQueue.popLast() else {
            DispatchQueue.main.async {
                self.curPlaying = nil
            }
            return
        }
        
        playWavData(nextItem)
    }
}
