import Foundation

struct AppUpdate: Codable {
    var version: String?
    var url: String?
    var info: String?

    var dataVersion2: String?
    var dataUrl2: String?
    var dataVersion3: String?
    var dataUrl3: String?
    var dataVersion4: String?
    var dataUrl4: String?

    enum CodingKeys: String, CodingKey {
        case version = "apk_version"
        case url = "apk_url"
        case info = "apk_info"
        case dataVersion2 = "data_version_2"
        case dataUrl2 = "data_url_2"
        case dataVersion3 = "data_version_3"
        case dataUrl3 = "data_url_3"
        case dataVersion4 = "data_version_4"
        case dataUrl4 = "data_url_4"
    }
}
