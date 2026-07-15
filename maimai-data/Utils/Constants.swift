import Foundation

enum Constants {
    static let genreUtage = "宴会場"
    static let chartTypeDX = "DX"
    static let chartTypeSD = "SD"

    static let divingFishBaseURL = "https://www.diving-fish.com"
    static let imageBaseURL = "https://maimaidx.jp/maimai-mobile/img/Music/"
    static let divingFishCoverURL = "https://www.diving-fish.com/covers/"
    static let updateManifestURL = "https://bucket-1256206908.cos.ap-shanghai.myqcloud.com/update.json"

    /// Wahlap proxy server URL, configured via Config.xcconfig → Info.plist.
    static let wahlapServerURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "WAHLAP_SERVER_URL") as? String
            ?? "http://127.0.0.1:8080"
    }()

    /// Construct the WeChat entry URL for a given task ID.
    static func wechatEntryURL(taskId: String) -> URL {
        URL(string: "\(wahlapServerURL)/tasks/\(taskId)")!
    }
}
