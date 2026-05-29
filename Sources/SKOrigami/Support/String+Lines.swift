import Foundation

extension String {
    var lines: [String] {
        split(whereSeparator: \.isNewline).map(String.init)
    }
}
