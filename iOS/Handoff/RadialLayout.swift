import CoreGraphics
import Foundation

/// Pure trigonometry for the constellation layout: N sibling nodes evenly spaced on a circle
/// around a center parent-avatar node, starting at 12 o'clock and proceeding clockwise. No
/// SwiftUI import — `ConstellationView` feeds these points straight into `.position(_:)`.
enum RadialLayout {

    /// The angle (radians, screen convention: 0 = 3 o'clock, increasing clockwise) for sibling
    /// `index` of `count`, starting at 12 o'clock (`-.pi/2`).
    static func angle(index: Int, count: Int) -> CGFloat {
        guard count > 0 else { return -CGFloat.pi / 2 }
        return -CGFloat.pi / 2 + (CGFloat(index) / CGFloat(count)) * 2 * CGFloat.pi
    }

    /// The point on a circle of `radius` around `center` for sibling `index` of `count`.
    static func position(index: Int, count: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let theta = angle(index: index, count: count)
        return CGPoint(x: center.x + cos(theta) * radius, y: center.y + sin(theta) * radius)
    }

    /// A control point for a gentle outward-bulging quadratic curve between two points, used so
    /// the "handoff glow" arcs read as curved constellation lines rather than straight spokes.
    static func bulgeControlPoint(from: CGPoint, to: CGPoint, center: CGPoint, bulge: CGFloat = 0.22) -> CGPoint {
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let awayX = mid.x - center.x
        let awayY = mid.y - center.y
        let length = max(sqrt(awayX * awayX + awayY * awayY), 1)
        let normX = awayX / length
        let normY = awayY / length
        let spread = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
        return CGPoint(x: mid.x + normX * spread * bulge, y: mid.y + normY * spread * bulge)
    }

    /// A point at parameter `t` (0...1) along the quadratic Bezier curve from `p0` to `p1` with
    /// control point `control` — used to animate the "handoff glow" dot along the same curved
    /// arcs the static constellation lines are drawn with.
    static func quadraticPoint(_ t: CGFloat, p0: CGPoint, control: CGPoint, p1: CGPoint) -> CGPoint {
        let oneMinusT = 1 - t
        let x = oneMinusT * oneMinusT * p0.x + 2 * oneMinusT * t * control.x + t * t * p1.x
        let y = oneMinusT * oneMinusT * p0.y + 2 * oneMinusT * t * control.y + t * t * p1.y
        return CGPoint(x: x, y: y)
    }
}
