import CoreGraphics

public enum ScreenDirection {
    case left, right, up, down

    // Project the display onto an axis that increases in the requested direction.
    fileprivate func edges(of frame: CGRect) -> (near: CGFloat, far: CGFloat, crossMin: CGFloat, crossMax: CGFloat) {
        switch self {
        case .left: return (-frame.maxX, -frame.minX, frame.minY, frame.maxY)
        case .right: return (frame.minX, frame.maxX, frame.minY, frame.maxY)
        case .up: return (-frame.maxY, -frame.minY, frame.minX, frame.maxX)
        case .down: return (frame.minY, frame.maxY, frame.minX, frame.maxX)
        }
    }
}

/// Both frames use Accessibility's top-left coordinate system.
public struct WindowDisplay: Equatable {
    public let frame: CGRect
    public let visibleFrame: CGRect

    public init(frame: CGRect, visibleFrame: CGRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

extension WindowGeometry {
    public static func display(for window: CGRect, among displays: [WindowDisplay]) -> WindowDisplay? {
        func rank(_ display: WindowDisplay) -> (CGFloat, CGFloat) {
            let overlap = window.intersection(display.frame)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            let distance = hypot(window.midX - display.frame.midX, window.midY - display.frame.midY)
            return (-area, distance)
        }
        return displays.min { rank($0) < rank($1) }
    }

    public static func destination(from source: WindowDisplay, toward direction: ScreenDirection,
                                   among displays: [WindowDisplay]) -> WindowDisplay? {
        let origin = direction.edges(of: source.frame)
        var best: (display: WindowDisplay, rank: (Int, CGFloat, CGFloat))?
        for display in displays {
            let edges = direction.edges(of: display.frame)
            let gap = edges.near - origin.far
            guard gap >= 0 else { continue }
            let crossGap = max(edges.crossMin - origin.crossMax, origin.crossMin - edges.crossMax)
            let centerOffset = abs(edges.crossMin + edges.crossMax - origin.crossMin - origin.crossMax)
            // Prefer displays that share an edge or overlap on the perpendicular axis.
            let rank = (crossGap < 0 ? 0 : 1, hypot(gap, max(0, crossGap)), centerOffset)
            if let best, best.rank <= rank { continue }
            best = (display, rank)
        }
        return best?.display
    }

    public static func transferred(_ window: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
        func offset(_ position: CGFloat, available: CGFloat, destinationSpace: CGFloat) -> CGFloat {
            guard available > 0 else { return 0 }
            return min(1, max(0, position / available)) * destinationSpace
        }
        let width = min(window.width, destination.width)
        let height = min(window.height, destination.height)
        return CGRect(
            x: destination.minX + offset(window.minX - source.minX, available: source.width - window.width,
                                         destinationSpace: destination.width - width),
            y: destination.minY + offset(window.minY - source.minY, available: source.height - window.height,
                                         destinationSpace: destination.height - height),
            width: width, height: height
        )
    }
}
