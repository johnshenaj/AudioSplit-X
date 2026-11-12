import XCTest
import AudioToolbox
@testable import AudioCore

final class RenderTests: XCTestCase {
    func format(nonInterleaved: Bool) -> AudioStreamBasicDescription {
        AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | (nonInterleaved ? kAudioFormatFlagIsNonInterleaved : 0),
            mBytesPerPacket: nonInterleaved ? 4 : 8, mFramesPerPacket: 1,
            mBytesPerFrame: nonInterleaved ? 4 : 8, mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
    }
    func testStereoGainMuteAndShortBuffers() {
        let input = AudioBufferList.allocate(maximumBuffers: 2)
        let output = AudioBufferList.allocate(maximumBuffers: 1)
        defer { free(input.unsafeMutablePointer); free(output.unsafeMutablePointer) }
        let l = UnsafeMutablePointer<Float>.allocate(capacity: 3)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: 2)
        let result = UnsafeMutablePointer<Float>.allocate(capacity: 6)
        defer { l.deallocate(); r.deallocate(); result.deallocate() }
        l.initialize(from: [0.8, -0.6, 0.9], count: 3)
        r.initialize(from: [0.4, -0.2], count: 2)
        result.initialize(repeating: 99, count: 6)
        input[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: 12, mData: l)
        input[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: 8, mData: r)
        output[0] = AudioBuffer(mNumberChannels: 2, mDataByteSize: 24, mData: result)
        var params = RouteParameters(); params.volume = 0.5
        RouteEngine.render(input: input.unsafePointer, inputFormat: format(nonInterleaved: true), inputBufferOffset: 0,
            output: output.unsafeMutablePointer, outputFormat: format(nonInterleaved: false), parameters: params, parametersStorage: nil)
        for (index, expected) in [Float(0.4), 0.2, -0.3, -0.1, 0, 0].enumerated() {
            XCTAssertEqual(result[index], expected, accuracy: 0.00001)
        }
        params.muted = 1
        RouteEngine.render(input: input.unsafePointer, inputFormat: format(nonInterleaved: true), inputBufferOffset: 0,
            output: output.unsafeMutablePointer, outputFormat: format(nonInterleaved: false), parameters: params, parametersStorage: nil)
        XCTAssertTrue((0..<6).allSatisfy { result[$0] == 0 })
    }
}
