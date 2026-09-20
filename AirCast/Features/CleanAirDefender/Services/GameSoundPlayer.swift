import AVFoundation

/// Lightweight, fully procedural sound effects for Clean Air Defender.
///
/// Every cue is a short synthesized tone (sine waves with a simple
/// attack/decay envelope), rendered once at init and replayed through a
/// small pool of `AVAudioPlayerNode`s — no bundled audio assets and no
/// third-party dependency, matching work order §6/§17 ("native/lightweight
/// feedback... if no sound assets already exist, do not block the feature
/// on sound") without pulling in unlicensed audio for a CAC submission.
///
/// Every cue here already has a visual and/or haptic equivalent elsewhere
/// (splash, popup, callout banner, HUD) — sound is strictly additive
/// (work order §16: "sound must not be required").
final class GameSoundPlayer {
    /// The single source of truth for the sound-on/off preference key —
    /// referenced by both `@AppStorage` usages (Entry screen's toggle,
    /// `CleanAirDefenderGameView`'s live binding) and the raw
    /// `UserDefaults` read at scene-construction time, so the three can
    /// never silently drift apart from a typo/rename in only one place.
    static let preferenceKey = "ac.cleanAirDefender.soundEnabled"

    enum Cue {
        case lightHit
        case mediumHit
        case heavyHit
        case boostActivate
        case incorrectHit
        case roundComplete
    }

    private static let sampleRate: Double = 44_100
    private static let voiceCount = 4

    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoiceIndex = 0
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var isEnabled: Bool
    private var engineStarted = false

    /// Fails only if the platform can't produce a standard mono float audio
    /// format at all (never observed in practice) — callers treat a nil
    /// player exactly like a disabled one, since sound is additive-only.
    init?(enabled: Bool) {
        guard let resolvedFormat = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1) else {
            return nil
        }
        self.isEnabled = enabled
        format = resolvedFormat
        for _ in 0..<Self.voiceCount {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
            voices.append(voice)
        }
        let rendered: [Cue: AVAudioPCMBuffer?] = [
            .lightHit: Self.makeTone(notes: [(880, 0.07, 0)], sampleRate: Self.sampleRate),
            .mediumHit: Self.makeTone(notes: [(659, 0.09, 0)], sampleRate: Self.sampleRate),
            .heavyHit: Self.makeTone(notes: [(440, 0.11, 0), (220, 0.11, 0)], sampleRate: Self.sampleRate, mix: true),
            .boostActivate: Self.makeTone(notes: [(660, 0.08, 0), (880, 0.12, 0.07)], sampleRate: Self.sampleRate),
            .incorrectHit: Self.makeTone(notes: [(200, 0.14, 0)], sampleRate: Self.sampleRate, waveform: .softBuzz),
            .roundComplete: Self.makeTone(notes: [(523, 0.1, 0), (659, 0.1, 0.09), (784, 0.16, 0.18)], sampleRate: Self.sampleRate),
        ]
        buffers = rendered.compactMapValues { $0 }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func play(_ cue: Cue) {
        guard isEnabled, let buffer = buffers[cue] else { return }
        ensureEngineRunning()
        guard engineStarted else { return }
        let voice = voices[nextVoiceIndex]
        nextVoiceIndex = (nextVoiceIndex + 1) % voices.count
        voice.stop()
        voice.scheduleBuffer(buffer, at: nil, options: [.interrupts])
        voice.play()
    }

    /// Lazily starts the audio session/engine on first real use rather than
    /// at init — avoids claiming an audio session for a screen the user
    /// might never actually play a round on. `.ambient` respects the
    /// device's silent switch, matching how a considerate game (not a
    /// media player) should behave: sound is a bonus, never forced on a
    /// muted phone (work order §16/§17).
    private func ensureEngineRunning() {
        guard !engineStarted else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            engineStarted = true
        } catch {
            // Never surfaces to the player — sound is additive only.
            engineStarted = false
        }
    }

    // MARK: Synthesis

    private enum Waveform {
        case sine
        case softBuzz
    }

    /// Renders one or more short tone segments (each with its own
    /// frequency/duration/start offset) into a single buffer sized to fit
    /// them all, with a fast linear attack and exponential-ish decay so
    /// nothing clicks or pops at the edges.
    private static func makeTone(
        notes: [(frequency: Double, duration: Double, startOffset: Double)],
        sampleRate: Double,
        mix: Bool = false,
        waveform: Waveform = .sine
    ) -> AVAudioPCMBuffer? {
        let totalDuration = mix
            ? (notes.map(\.duration).max() ?? 0.1)
            : (notes.map { $0.startOffset + $0.duration }.max() ?? 0.1)
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration) + 1
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return buffer }
        for i in 0..<Int(frameCount) { channel[i] = 0 }

        for note in notes {
            let startFrame = Int(note.startOffset * sampleRate)
            let noteFrames = Int(note.duration * sampleRate)
            let attackFrames = max(1, Int(0.006 * sampleRate))
            for n in 0..<noteFrames {
                let frame = startFrame + n
                guard frame >= 0, frame < Int(frameCount) else { continue }
                let t = Double(n) / sampleRate
                let progress = Double(n) / Double(max(noteFrames - 1, 1))
                let envelope: Double
                if n < attackFrames {
                    envelope = Double(n) / Double(attackFrames)
                } else {
                    envelope = pow(1.0 - progress, 1.6)
                }
                let raw: Double
                switch waveform {
                case .sine:
                    raw = sin(2 * .pi * note.frequency * t)
                case .softBuzz:
                    // A touch of second-harmonic content for a gentle
                    // "buzz" rather than a pure tone — still soft, matching
                    // the work order's "avoid highly punishing mechanics."
                    raw = sin(2 * .pi * note.frequency * t) * 0.75 + sin(2 * .pi * note.frequency * 2 * t) * 0.25
                }
                let sample = Float(raw * envelope * 0.5)
                channel[frame] += sample
            }
        }
        return buffer
    }
}
