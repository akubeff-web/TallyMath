import Testing
@testable import MathCore

@Suite("Решатели")
struct SolverTests {
    func solve(_ s: String) throws -> SolutionSet { try Solver.solve(Parser.statement(s)) }
    func values(_ list: [String]) throws -> SolutionSet {
        .values(try list.map { try #require(try Parser.expression($0).value()) })
    }

    @Test func linear() throws {
        #expect(try solve("2x + 5 = 17") == values(["6"]))
        #expect(try solve("3(x − 1) = 2x + 4") == values(["7"]))
        #expect(try solve("x + 1 = x + 2") == .none)
        #expect(try solve("2(x + 1) = 2x + 2") == .all(except: []))
    }

    @Test func quadratic() throws {
        #expect(try solve("x² − 5x + 6 = 0") == values(["2", "3"]))
        #expect(try solve("x² = 2") == values(["√2", "−√2"]))
        #expect(try solve("x² + 1 = 0") == .none)
        #expect(try solve("x² − 4x + 4 = 0") == values(["2"]))
        #expect(try solve("2x² − 3x − 2 = 0") == values(["2", "−1/2"]))
        #expect(try solve("x² − 2x − 1 = 0") == values(["1 + √2", "1 − √2"]))
    }

    @Test func rationalEquationDropsExtraneousRoots() throws {
        // (x² − 1)/(x − 1) = 2 → x + 1 = 2, x = 1 — но x ≠ 1.
        #expect(try solve("{x² − 1}/{x − 1} = 2") == .none)
        #expect(try solve("{x}/{x − 2} = {2}/{x − 2}") == .none)
        #expect(try solve("{1}/{x} = {2}/{x + 1}") == values(["1"]))
    }

    @Test func absoluteValue() throws {
        #expect(try solve("|x − 2| = 3") == values(["5", "−1"]))
        #expect(try solve("|x| = −1") == .none)
    }

    @Test func answersInAnyOrder() throws {
        #expect(try solve("x₁ = 3 или x₂ = 2") == solve("x² − 5x + 6 = 0"))
        #expect(try solve("x = 6") == solve("2x + 5 = 17"))
        #expect(try solve("нет решений") == solve("x² + 1 = 0"))
    }

    @Test func inequalities() throws {
        #expect(try solve("2x − 3 > 5") == solve("x ∈ (4; +∞)"))
        #expect(try solve("−3x ≤ 6") == solve("[−2; +∞)"))
        #expect(try solve("x > 4") == solve("(4; +∞)"))
        #expect(try solve("−3x ≤ 6") != solve("(−∞; −2]"))
        #expect(try solve("1 < x ≤ 5") == solve("(1; 5]"))
        #expect(try solve("x² − 5x + 6 < 0") == solve("(2; 3)"))
        #expect(try solve("x² − 1 ≥ 0") == solve("(−∞; −1] ∪ [1; +∞)"))
    }

    @Test func systems() throws {
        #expect(try solve("2x + y = 5; x − y = 1") == .point(["x": .of(2), "y": .of(1)]))
        #expect(try solve("x + y = 1; 2x + 2y = 3") == .none)
        #expect(try solve("x + y = 1; 2x + 2y = 2") == .infinite)
        #expect(try solve("x > 1; x < 4") == solve("(1; 4)"))
    }
}
