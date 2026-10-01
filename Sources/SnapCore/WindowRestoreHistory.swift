import CoreGraphics

/// The first frame is retained until restoration succeeds. Each window has its own snapshot.
public struct WindowRestoreHistory<Window: Hashable> {
    private var frames: [Window: CGRect] = [:]

    public init() {}

    public mutating func remember(_ frame: CGRect, for window: Window) {
        if frames[window] == nil { frames[window] = frame }
    }

    public func originalFrame(for window: Window) -> CGRect? { frames[window] }

    public mutating func forget(_ window: Window) { frames.removeValue(forKey: window) }

    public mutating func forget(where predicate: (Window) -> Bool) {
        frames = frames.filter { !predicate($0.key) }
    }
}
