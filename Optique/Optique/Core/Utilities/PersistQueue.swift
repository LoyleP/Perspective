import Foundation

/// Where stores write to disk: one serial background queue, so encoding a list of stories and writing it never
/// blocks the main thread (a bookmark tap or a story opening), and writes land in the order they were made.
enum PersistQueue {
    static let queue = DispatchQueue(label: "com.flow.optique.persist", qos: .utility)
}
