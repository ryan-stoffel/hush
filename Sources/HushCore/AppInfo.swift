import Foundation

public enum AppInfo {
    public static let name = "Hush"
    public static let bundleIdentifier = "io.github.ryan-stoffel.hush"
    public static let repositoryURL = URL(string: "https://github.com/ryan-stoffel/hush")

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
