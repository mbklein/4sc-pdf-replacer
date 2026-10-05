// Usage: replace4sc file.4sc new.pdf
//        replace4sc --version
import Foundation
import FourScoreKit

let args = CommandLine.arguments
let program = (args[0] as NSString).lastPathComponent

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

if args.count == 2, ["--version", "-V"].contains(args[1]) {
    print("\(program) \(FourScoreVersion.string)")
    exit(0)
}

guard args.count == 3 else { fail("Usage: \(program) file.4sc new.pdf") }
let src = args[1], pdf = args[2]

do {
    let report = try FourScoreFile.replacePDF(in: URL(fileURLWithPath: src), with: URL(fileURLWithPath: pdf))
    for warning in report.warnings {
        FileHandle.standardError.write(Data("Warning: \(warning)\n".utf8))
    }
    print("Replaced pdfData in \(src)")
} catch {
    fail(error.localizedDescription)
}
