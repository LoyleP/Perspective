import Foundation

enum AppError: LocalizedError, Sendable, Equatable {
    case networkUnavailable
    case serverError
    case dataCorrupted
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Impossible de se connecter. Vérifiez votre connexion internet."
        case .serverError:
            return "Le serveur ne répond pas. Réessayez plus tard."
        case .dataCorrupted:
            return "Les données reçues sont invalides."
        case .unknown(let message):
            return "Une erreur s'est produite : \(message)"
        }
    }

    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotConnectToHost:
                return .networkUnavailable
            case NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost:
                return .serverError
            default:
                return .unknown(error.localizedDescription)
            }
        }

        if error is DecodingError {
            return .dataCorrupted
        }

        return .unknown(error.localizedDescription)
    }
}
