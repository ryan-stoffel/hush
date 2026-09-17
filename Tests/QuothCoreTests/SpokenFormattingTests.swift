import XCTest
@testable import QuothCore

final class SpokenFormattingTests: XCTestCase {
    private func format(_ text: String, language: String? = "en") throws -> String {
        try SpokenFormatting().process(text, context: CleanupContext(language: language))
    }

    func testCommands() throws {
        let cases: [(String, String)] = [
            ("hello comma how are you", "hello, how are you"),
            ("that works period", "that works."),
            ("that works full stop next thing", "that works. Next thing"),
            ("are you coming question mark", "are you coming?"),
            ("watch out exclamation point", "watch out!"),
            ("watch out exclamation mark run", "watch out! Run"),
            ("three things colon speed", "three things: speed"),
            ("it works semicolon mostly", "it works; mostly"),
            ("fast dash really fast", "fast - really fast"),
            ("the result open paren so far close paren is good", "the result (so far) is good"),
            ("the result open parenthesis so far close parenthesis is good", "the result (so far) is good"),
            ("she said open quote hello close quote loudly", "she said \"hello\" loudly"),
            ("she said open quote hello unquote loudly", "she said \"hello\" loudly"),
            ("she said open quote hello end quote", "she said \"hello\""),
            ("first line new line second line", "first line\nSecond line"),
            ("first line newline second line", "first line\nSecond line"),
            ("first line next line second line", "first line\nSecond line"),
            ("intro new paragraph body", "intro\n\nBody"),
            ("Hi Sam comma new line thanks for the update period", "Hi Sam,\nThanks for the update."),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(try format(input), expected, input)
        }
    }

    func testModelPunctuationAroundCommandsIsCollapsed() throws {
        let cases: [(String, String)] = [
            ("Are you coming question mark?", "Are you coming?"),
            ("Are you coming, question mark.", "Are you coming?"),
            ("That works, period.", "That works."),
            ("Hello, comma, how are you?", "Hello, how are you?"),
            ("First line. New line. Second line.", "First line.\nSecond line."),
            ("First line, new line, second line.", "First line\nSecond line."),
            ("Intro. New paragraph. Body text.", "Intro.\n\nBody text."),
            ("Wow exclamation point!", "Wow!"),
            ("Line one. New line. New line. Line two.", "Line one.\nLine two."),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(try format(input), expected, input)
        }
    }

    func testMentionsOfCommandWordsSurvive() throws {
        let sentences = [
            "the period of time was long",
            "That is a comma splice.",
            "put a question mark after it",
            "We waited for a long period.",
            "Add a new line of code here.",
            "The new line looks better.",
            "He made a dash for the door.",
            "Press the colon key.",
            "This paragraph needs an exclamation point.",
            "I like that bullet point.",
            "a period of calm",
        ]
        for sentence in sentences {
            XCTAssertEqual(try format(sentence), sentence, sentence)
        }
    }

    func testBullets() throws {
        XCTAssertEqual(
            try format("Groceries colon bullet point milk next bullet eggs next bullet bread"),
            "Groceries:\n- Milk\n- Eggs\n- Bread"
        )
        XCTAssertEqual(try format("Bullet point milk. Bullet point eggs."), "- Milk.\n- Eggs.")
        XCTAssertEqual(try format("todo, bullet point, call Sam"), "todo\n- Call Sam")
    }

    func testNumberedLists() throws {
        let cases: [(String, String)] = [
            ("One, apples. Two, bananas. Three, cherries.", "1. Apples\n2. Bananas\n3. Cherries"),
            ("My list: one, apples. Two, bananas.", "My list:\n1. Apples\n2. Bananas"),
            ("First, preheat the oven. Second, mix the flour.", "1. Preheat the oven\n2. Mix the flour"),
            ("1. apples 2. bananas", "1. apples 2. bananas"),
            ("Steps: 1. Open the app. 2. Hold Fn.", "Steps:\n1. Open the app\n2. Hold Fn"),
            (
                "Agenda colon one, budget. Two, hiring. Is that ok? Yes.",
                "Agenda:\n1. Budget\n2. Hiring. Is that ok? Yes."
            ),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(try format(input), expected, input)
        }
    }

    func testThingsThatAreNotLists() throws {
        let sentences = [
            "I have one apple and two pears.",
            "One, that is not going to work.",
            "Two, apples. One, bananas.",
            "We won three to one.",
            "First, thank you all for coming.",
        ]
        for sentence in sentences {
            XCTAssertEqual(try format(sentence), sentence, sentence)
        }
    }

    func testListItemsCanFollowLineBreakCommands() throws {
        XCTAssertEqual(
            try format("Plan colon new line one, ship it. Two, test it."),
            "Plan:\n1. Ship it\n2. Test it"
        )
    }

    /// Transcripts produced by the base Whisper model from synthesized speech.
    func testRealModelOutput() throws {
        let cases: [(String, String)] = [
            (
                "Shopping list colon new line. One, apples, two bananas, three, cherries.",
                "Shopping list:\n1. Apples\n2. Bananas\n3. Cherries"
            ),
            (
                "Thanks for the update period new paragraph can we meet Tuesday question mark.",
                "Thanks for the update.\n\nCan we meet Tuesday?"
            ),
            (
                "Things to do, bullet point, call the bank, bullet point email Priya, bullet point book flights.",
                "Things to do\n- Call the bank\n- Email Priya\n- Book flights."
            ),
            (
                "First, open the app, second, hold the function key, third, start talking.",
                "1. Open the app\n2. Hold the function key\n3. Start talking"
            ),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(try format(input), expected, input)
        }
    }

    func testOtherLanguagesAreLeftAlone() throws {
        XCTAssertEqual(try format("hola comma que tal", language: "es"), "hola comma que tal")
        XCTAssertEqual(try format("hello comma there", language: nil), "hello, there")
        XCTAssertEqual(try format("hello comma there", language: "en-GB"), "hello, there")
    }

    func testPlainTextIsUntouched() throws {
        for text in ["", "Just a normal sentence.", "Send the report on Wednesday, and copy Priya."] {
            XCTAssertEqual(try format(text), text)
        }
    }

    func testStageKeepsWorkingWhenCleanupIsOff() async {
        let settings = SettingsStore.inMemory()
        settings.set(SettingKeys.cleanupEnabled, to: false)
        let pipeline = CleanupPipeline(stages: CleanupStages.standard, settings: settings)
        let result = await pipeline.run("one new line two", context: CleanupContext(language: "en"))
        XCTAssertEqual(result.finalText, "one\nTwo")

        settings.set(SpokenFormatting().enabledKey, to: false)
        let off = await pipeline.run("one new line two", context: CleanupContext(language: "en"))
        XCTAssertEqual(off.finalText, "one new line two")
    }
}
