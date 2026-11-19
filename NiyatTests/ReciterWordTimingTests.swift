import AVFoundation
import XCTest
@testable import Niyat

/// Following a reciter's recording word by word with the built-in model:
/// where the aligner places each word, and which words count as placed.
final class ReciterWordTimingTests: XCTestCase {
    private let pieces = ["<unk>", "▁الْ", "حَمْ", "دُ", "▁لِلَّهِ", "▁رَبِّ", "▁العا", "لَمِينَ", "▁"]
        + "ابتثجحخدذرزسشصضطظعغفقكلمنهوي".map(String.init) + ["<blk>"]

    /// Each piece clearly heard in the middle of `framesPerPiece` frames of blank.
    private func heard(_ said: [String], vocabulary: RecitationVocabulary, framesPerPiece: Int = 8) -> RecitationLogProbs {
        var values: [Float] = []
        for piece in said {
            let id = pieces.firstIndex(of: piece)!
            for frame in 0..<framesPerPiece {
                var row = [Float](repeating: -9, count: pieces.count)
                row[frame == framesPerPiece / 2 ? id : vocabulary.blank] = -0.01
                values += row
            }
        }
        return RecitationLogProbs(frames: said.count * framesPerPiece, vocabulary: pieces.count, values: values)
    }

    private func letters(_ words: [String]) -> [[[UInt32]]] {
        words.map { [RecitationMatcher.normalize($0).unicodeScalars.map(\.value)] }
    }

    func testWordsStartWhereTheirFirstPieceIsHeard() throws {
        let vocabulary = RecitationVocabulary(pieces: pieces)
        // الحمد = 3 pieces (frames 0-23), لله (24-31), رب (32-39), العالمين (40-55).
        let lp = heard(["▁الْ", "حَمْ", "دُ", "▁لِلَّهِ", "▁رَبِّ", "▁العا", "لَمِينَ"], vocabulary: vocabulary)
        let scores = try XCTUnwrap(RecitationAligner.align(lp, vocabulary: vocabulary,
                                                           words: letters(["الحمد", "لله", "رب", "العالمين"])))
        let starts = scores.map(\.start)
        XCTAssertEqual(starts, starts.sorted(), "words start in order")
        // Each word starts no later than its first piece is heard (frame 4 of
        // its first piece), and after the previous word's last piece.
        for (word, heardAt, previousEnd) in [(1, 28, 20), (2, 36, 28), (3, 44, 36)] {
            XCTAssertLessThanOrEqual(starts[word], heardAt, "word \(word)")
            XCTAssertGreaterThan(starts[word], previousEnd, "word \(word)")
        }
    }

    func testOnlyClearlyHeardWordsArePlaced() {
        let scores = [
            RecitationAligner.Score(pieces: [-0.1], start: 0),
            RecitationAligner.Score(pieces: [-8], start: 10),
            RecitationAligner.Score(pieces: [-0.5, -1], start: 25),
        ]
        let anchors = ReciterModelTimings.anchors(scores: scores, secondsPerFrame: 0.08)
        XCTAssertEqual(anchors.keys.sorted(), [0, 2])
        XCTAssertEqual(anchors[2] ?? 0, 2.0, accuracy: 0.0001)
    }

    func testUsableNeedsMostWordsInOrder() {
        XCTAssertTrue(WordTimingAligner.isUsable([0: 0, 1: 0.5, 2: 1.0], count: 4))
        XCTAssertFalse(WordTimingAligner.isUsable([0: 0, 3: 1.0], count: 4), "only half the words placed")
        XCTAssertFalse(WordTimingAligner.isUsable([0: 1.0, 1: 0.5, 2: 1.2], count: 3), "out of order")
    }

    func testSpellingsIncludeEveryAcceptedForm() {
        let token = RecitationTracker.Token(id: WordID(surah: 1, verse: 1, index: 0), forms: ["الرحمن", "ٱلرَّحْمَٰنِ"])
        XCTAssertEqual(ReciterModelTimings.spellings([token]).first?.count, 2)
    }

    func testReadsAWholeRecordingAt16kHz() throws {
        // 1.3 s at 44.1 kHz: not a whole number of read chunks, so the last
        // read is short (reading past the end used to throw).
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tone-\(UUID()).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let frames = AVAudioFrameCount(44_100 * 1.3)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        for i in 0..<Int(frames) { buffer.floatChannelData![0][i] = Float(0.3 * sin(2 * .pi * 440 * Double(i) / 44_100)) }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let samples = try ReciterModelTimings.samples(from: url)
        XCTAssertEqual(Double(samples.count), 16_000 * 1.3, accuracy: 200)
    }
}
