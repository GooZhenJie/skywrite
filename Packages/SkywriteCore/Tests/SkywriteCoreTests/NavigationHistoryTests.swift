import SkywriteCore
import Testing

@Suite struct NavigationHistoryTests {
    @Test func startsWithNowhereToGo() {
        let history = NavigationHistory("general")
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)
    }

    @Test func backAndForwardRetraceTheVisits() {
        var history = NavigationHistory("general")
        history.visit("appearance")
        history.visit("storage")
        history.goBack()
        #expect(history.current == "appearance")
        history.goBack()
        #expect(history.current == "general")
        #expect(!history.canGoBack)
        history.goForward()
        history.goForward()
        #expect(history.current == "storage")
        #expect(!history.canGoForward)
    }

    @Test func visitingAfterGoingBackDropsTheForwardList() {
        var history = NavigationHistory("general")
        history.visit("appearance")
        history.goBack()
        history.visit("shortcuts")
        #expect(!history.canGoForward)
        history.goBack()
        #expect(history.current == "general")
    }

    @Test func visitingTheSamePaneAddsNothing() {
        var history = NavigationHistory("general")
        history.visit("general")
        #expect(!history.canGoBack)
    }
}
