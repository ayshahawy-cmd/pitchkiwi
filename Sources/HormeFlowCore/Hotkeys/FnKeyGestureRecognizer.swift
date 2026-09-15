import Foundation

enum FnGestureCommand: Equatable {
    case start
    case stop
    case lockHandsFree
}

struct FnKeyGestureRecognizer {
    static let doublePressWindow: TimeInterval = 0.32

    private enum State: Equatable {
        case idle
        case pressing(startedAt: TimeInterval)
        case waitingForSecondPress(deadline: TimeInterval)
        case handsFree
    }

    private var state: State = .idle

    var isWaitingForSecondPress: Bool {
        if case .waitingForSecondPress = state { return true }
        return false
    }

    mutating func keyDown(at timestamp: TimeInterval) -> [FnGestureCommand] {
        switch state {
        case .idle:
            state = .pressing(startedAt: timestamp)
            return [.start]
        case .pressing:
            return []
        case let .waitingForSecondPress(deadline):
            guard timestamp <= deadline else {
                state = .idle
                return [.stop]
            }
            state = .handsFree
            return [.lockHandsFree]
        case .handsFree:
            state = .idle
            return [.stop]
        }
    }

    mutating func keyUp(at timestamp: TimeInterval) -> [FnGestureCommand] {
        guard case let .pressing(startedAt) = state else { return [] }

        if timestamp - startedAt >= Self.doublePressWindow {
            state = .idle
            return [.stop]
        }

        state = .waitingForSecondPress(deadline: timestamp + Self.doublePressWindow)
        return []
    }

    mutating func timeout(at timestamp: TimeInterval) -> [FnGestureCommand] {
        guard case let .waitingForSecondPress(deadline) = state,
              timestamp >= deadline else { return [] }
        state = .idle
        return [.stop]
    }

    mutating func reset() {
        state = .idle
    }
}
