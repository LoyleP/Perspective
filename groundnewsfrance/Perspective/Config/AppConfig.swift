import Foundation

enum AppConfig {
    static let supabaseURL: String = {
        // Keys are set via Xcode build settings (INFOPLIST_KEY_SupabaseURL)
        guard let url = Bundle.main.infoDictionary?["SupabaseURL"] as? String else {
            fatalError("SupabaseURL not configured in build settings")
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        // Keys are set via Xcode build settings (INFOPLIST_KEY_SupabaseAnonKey)
        guard let key = Bundle.main.infoDictionary?["SupabaseAnonKey"] as? String else {
            fatalError("SupabaseAnonKey not configured in build settings")
        }
        return key
    }()
}
