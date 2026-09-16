#!/usr/bin/env xcrun swift
// Extract PNG frames from a generated move clip (Grok Imagine etc.) at a fixed rate.
// No ffmpeg on the dev Mac, so this mirrors the AVAssetImageGenerator bake in GameAssets.
//
//   xcrun swift tools/clip2sheet.swift <clip.mp4> <out-dir> [--fps 12] [--start 0.0] [--end 9.9]
//
// Frames land as <out-dir>/frame_000.png … then `tools/pack_sheet.py` keys and packs them.
import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else {
    fail("usage: clip2sheet.swift <clip.mp4> <out-dir> [--fps 12] [--start s] [--end s]")
}
let clipPath = args.removeFirst()
let outDir = args.removeFirst()
var fps: Double = 12
var start: Double = 0
var end: Double = .infinity
var i = 0
while i < args.count {
    switch args[i] {
    case "--fps": fps = Double(args[i + 1]) ?? fps; i += 2
    case "--start": start = Double(args[i + 1]) ?? start; i += 2
    case "--end": end = Double(args[i + 1]) ?? end; i += 2
    default: fail("unknown arg \(args[i])")
    }
}

let url = URL(fileURLWithPath: clipPath)
guard FileManager.default.fileExists(atPath: url.path) else { fail("missing clip: \(clipPath)") }
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let asset = AVURLAsset(url: url)
let semaphore = DispatchSemaphore(value: 0)
var duration: Double = 0
var natural = CGSize.zero
Task {
    do {
        duration = try await CMTimeGetSeconds(asset.load(.duration))
        if let track = try await asset.loadTracks(withMediaType: .video).first {
            natural = try await track.load(.naturalSize)
        }
    } catch {
        fail("cannot read clip: \(error)")
    }
    semaphore.signal()
}
semaphore.wait()
guard duration > 0 else { fail("zero-length clip") }

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero

let last = min(end, duration)
let step = 1.0 / fps
var index = 0
let done = DispatchSemaphore(value: 0)
Task {
    var t = max(0, start)
    while t < last - 1e-6 {
        let time = CMTime(seconds: t, preferredTimescale: 600)
        do {
            let (cg, _) = try await gen.image(at: time)
            let name = String(format: "frame_%03d.png", index)
            let dest = URL(fileURLWithPath: outDir).appendingPathComponent(name)
            guard let sink = CGImageDestinationCreateWithURL(dest as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                fail("cannot create \(name)")
            }
            CGImageDestinationAddImage(sink, cg, nil)
            guard CGImageDestinationFinalize(sink) else { fail("cannot write \(name)") }
            index += 1
        } catch {
            // Note: inside a sandbox VideoToolbox may refuse to decode ("Cannot Decode" -12911);
            // run from a normal terminal.
            FileHandle.standardError.write("skip t=\(String(format: "%.3f", t)): \(error.localizedDescription)\n".data(using: .utf8)!)
        }
        t += step
    }
    done.signal()
}
done.wait()
print("extracted \(index) frames @\(fps)fps from \(String(format: "%.2f", duration))s \(Int(natural.width))x\(Int(natural.height)) -> \(outDir)")
