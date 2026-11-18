import AVFoundation
import Foundation

/// Word timings for a reciter's recording from Niyat's built-in recitation
/// model (Hafs), on the iPhone and without asking for speech recognition.
///
/// The ayah's words are force-aligned to the recording (`RecitationAligner`),
/// which says where each word starts. Only words that fit the audio well
/// count as placed; the rest share the time between placed neighbours, as
/// with Apple's recogniser (see `WordTimingAligner.fill`).
enum ReciterModelTimings {
    /// A word whose alignment score is at least this was clearly heard (the
    /// threshold the research run used to tell said words from skipped ones).
    static let placedScore: Float = -3

    /// Start times (seconds) of the words that were placed, by word index.
    static func anchors(scores: [RecitationAligner.Score], secondsPerFrame: Double) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for (index, score) in scores.enumerated() where score.mean >= placedScore {
            result[index] = Double(score.start) * secondsPerFrame
        }
        return result
    }

    /// The words as the aligner wants them: every accepted spelling, as
    /// normalised letters.
    static func spellings(_ tokens: [RecitationTracker.Token]) -> [[[UInt32]]] {
        tokens.map { token in
            token.forms.map { RecitationMatcher.normalize($0).unicodeScalars.map(\.value) }.filter { !$0.isEmpty }
        }
    }

    /// Placed words and the recording's length, or nil if the model isn't in
    /// the app or the audio couldn't be read or aligned.
    static func align(file: URL, tokens: [RecitationTracker.Token]) async -> (anchors: [Int: Double], duration: Double)? {
        guard RecitationModel.isBundled, let samples = try? samples(from: file), !samples.isEmpty else { return nil }
        let duration = Double(samples.count) / Double(RecitationFeatures.sampleRate)
        guard let result = try? await RecitationModel.shared.wordScores(samples, words: spellings(tokens)) else { return nil }
        return (anchors(scores: result.scores, secondsPerFrame: duration / Double(max(result.frames, 1))), duration)
    }

    /// The whole file as 16 kHz mono samples, as the model listens.
    static func samples(from file: URL) throws -> [Float] {
        let audio = try AVAudioFile(forReading: file)
        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(RecitationFeatures.sampleRate),
                                         channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: audio.processingFormat, to: target) else { return [] }
        let chunk: AVAudioFrameCount = 16_384
        var samples: [Float] = []
        var finished = false
        while !finished {
            // Reading past the end throws, so read only what's left.
            let remaining = AVAudioFrameCount(max(0, audio.length - audio.framePosition))
            let count = min(chunk, remaining)
            guard let input = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: chunk) else { break }
            if count > 0 { try audio.read(into: input, frameCount: count) }
            finished = count == 0 || input.frameLength == 0
            let capacity = AVAudioFrameCount(Double(chunk) * target.sampleRate / audio.processingFormat.sampleRate) + 64
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { break }
            var given = false
            var error: NSError?
            _ = converter.convert(to: output, error: &error) { _, status in
                if given || finished {
                    status.pointee = finished ? .endOfStream : .noDataNow
                    return nil
                }
                given = true
                status.pointee = .haveData
                return input
            }
            if let error { throw error }
            if let channel = output.floatChannelData?[0], output.frameLength > 0 {
                samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
            }
        }
        return samples
    }
}

extension RecitationModel {
    /// How well, and from when, the audio fits each expected word.
    func wordScores(_ samples: [Float], words: [[[UInt32]]]) throws -> (scores: [RecitationAligner.Score], frames: Int)? {
        let lp = try logProbs(samples)
        guard let scores = check(lp, words: words) else { return nil }
        return (scores, lp.frames)
    }
}
