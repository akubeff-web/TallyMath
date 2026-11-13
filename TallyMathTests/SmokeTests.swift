import Testing
import MathCore

struct SmokeTests {
    @Test func mathCoreLinks() throws {
        #expect(try Parser.expression("1/3 + 1/6").rationalValue() == .of(1, 2))
    }
}
