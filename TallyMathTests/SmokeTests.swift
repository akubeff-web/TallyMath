import Testing
import MathCore
@testable import TallyMath

/// Тесты приложения: логика, которая живёт не в MathCore, а в модели приложения.
@MainActor
struct AppModelTests {
    @Test func mathCoreLinks() throws {
        #expect(try Parser.expression("1/3 + 1/6").rationalValue() == .of(1, 2))
    }

    @Test func tableFactParsing() {
        #expect(AppModel.tableFact("7 × 8")! == (7, 8))
        #expect(AppModel.tableFact("56 : 7")! == (7, 8))
        #expect(AppModel.tableFact("1/3 + 1/6") == nil)
    }

    @Test func demoDataHasWeakAndReviewTopics() {
        let today = AppModel.dayNumber()
        let store = DemoData.progress(today: today)
        #expect(store.isWeak("g6.addGen", day: today))
        #expect(store.dueReviews(day: today).contains("g5.sameAdd"))
    }

    @Test func sessionHasTenProblems() {
        let model = AppModel(demo: true)
        let problems = model.makeSession(SessionRequest(topicIDs: Course.fractionTopics))
        #expect(problems.count == 10)
        let review = model.makeSession(SessionRequest(topicIDs: ["g5.whole"], count: 5, isReview: true))
        #expect(review.count == 5)
    }

    @Test func speechIsReadable() {
        #expect(MathSpeech.speak("1/3 + 1/6").contains("плюс"))
    }

    @Test func whyContentLoadsAndIsHonest() {
        let all = WhyEntry.loadAll()
        for (_, e) in all {
            #expect(["нужно", "желательно", "можно пропустить"].contains(e.verdict), "\(e.topic): \(e.verdict)")
            for s in e.sources {
                #expect(s.url.hasPrefix("https://"), "\(e.topic): \(s.url)")
                #expect(!s.summary.isEmpty && !s.checked.isEmpty)
            }
        }
    }
}
