import Testing
import Foundation
@testable import Perspective

@Suite("AppError")
struct AppErrorTests {

    @Test("maps NSURLErrorNotConnectedToInternet to networkUnavailable")
    func mapsNetworkError() {
        let error = URLError(.notConnectedToInternet)
        #expect(AppError.from(error) == .networkUnavailable)
    }

    @Test("maps NSURLErrorNetworkConnectionLost to networkUnavailable")
    func mapsConnectionLost() {
        let error = URLError(.networkConnectionLost)
        #expect(AppError.from(error) == .networkUnavailable)
    }

    @Test("maps NSURLErrorTimedOut to serverError")
    func mapsTimeout() {
        let error = URLError(.timedOut)
        #expect(AppError.from(error) == .serverError)
    }

    @Test("maps DecodingError to dataCorrupted")
    func mapsDecodingError() {
        let error = DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "test")
        )
        #expect(AppError.from(error) == .dataCorrupted)
    }

    @Test("maps unknown error to unknown with message")
    func mapsUnknownError() {
        struct CustomError: Error, LocalizedError {
            var errorDescription: String? { "custom" }
        }
        let result = AppError.from(CustomError())
        #expect(result == .unknown("custom"))
    }

    @Test("passes through existing AppError")
    func passesThroughAppError() {
        let error = AppError.serverError
        #expect(AppError.from(error) == .serverError)
    }

    @Test("Equatable conformance works")
    func equatable() {
        #expect(AppError.networkUnavailable == AppError.networkUnavailable)
        #expect(AppError.networkUnavailable != AppError.serverError)
        #expect(AppError.unknown("a") == AppError.unknown("a"))
        #expect(AppError.unknown("a") != AppError.unknown("b"))
    }
}
