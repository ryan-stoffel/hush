import Foundation

public enum AppInfo {
    public static let name = "Quoth"
    public static let bundleIdentifier = "io.github.ryan-stoffel.quoth"
    public static let repositoryURL = URL(string: "https://github.com/ryan-stoffel/quoth")

    public static func version(in bundle: Bundle = .main) -> String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (short?, build?): return "\(short) (\(build))"
        case let (short?, nil): return short
        default: return "development"
        }
    }
}
