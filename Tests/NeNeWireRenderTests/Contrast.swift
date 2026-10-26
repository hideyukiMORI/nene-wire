// 移植元: NeNe Reversi `Tests/NeNeReversiRenderTests/Contrast.swift`（コミット dc418eb・その元は NeNe Gambit）。

@testable import NeNeWireRender

/// WCAG 2 のコントラスト比（相対輝度の比）。
enum Contrast {
    static func ratio(_ first: Rgb, _ second: Rgb) -> Double {
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    static func luminance(_ color: Rgb) -> Double {
        let channels = [color.red, color.green, color.blue].map { value -> Double in
            let c = Double(value) / 255
            return c <= 0.039_28 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    /// `pow` を Foundation 無しで（正の底と実数の指数）。
    static func pow(_ base: Double, _ exponent: Double) -> Double {
        (exponent * log(base)).exponential
    }

    static func log(_ value: Double) -> Double {
        // ln x = 2 * atanh((x - 1) / (x + 1)) の級数
        let y = (value - 1) / (value + 1)
        var term = y
        var sum = 0.0
        var n = 1.0
        for _ in 0..<60 {
            sum += term / n
            term *= y * y
            n += 2
        }
        return 2 * sum
    }
}

extension Double {
    /// e^x の級数。
    var exponential: Double {
        var term = 1.0
        var sum = 1.0
        for n in 1..<60 {
            term *= self / Double(n)
            sum += term
        }
        return sum
    }
}
