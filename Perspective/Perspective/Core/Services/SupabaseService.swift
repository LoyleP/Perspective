import Foundation
import Supabase

final class SupabaseService {

    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        guard
            let url = URL(string: AppConfig.supabaseURL)
        else {
            fatalError("SupabaseService: invalid URL in AppConfig.supabaseURL")
        }
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(decoder: Self.makeDecoder()),
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    // Handles both timestamptz ("2026-03-17T10:30:00+00:00") and
    // date-only ("2026-03-17") columns returned by Supabase/PostgREST.
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let iso = ISO8601DateFormatter()

            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }

            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: string) { return date }

            let dateFmt = DateFormatter()
            dateFmt.locale = Locale(identifier: "en_US_POSIX")
            dateFmt.timeZone = TimeZone(identifier: "UTC")
            dateFmt.dateFormat = "yyyy-MM-dd"
            if let date = dateFmt.date(from: string) { return date }

            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode date from string: \(string)"
                )
            )
        }
        return decoder
    }
}
