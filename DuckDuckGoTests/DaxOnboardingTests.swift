//
//  DaxOnboardingTests.swift
//  UnitTests
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
@testable import DuckDuckGo
@testable import Core

class DaxOnboardingTests: XCTestCase {
    
    struct URLs {
        
        static let example = URL(string: "https://www.example.com")!
        static let ddg = URL(string: "https://duckduckgo.com?q=test")!
        static let facebook = URL(string: "https://www.facebook.com")!
        static let google = URL(string: "https://www.google.com")!
        static let ownedByFacebook = URL(string: "https://www.instagram.com")!
        static let amazon = URL(string: "https://www.amazon.com")!

    }

    var onboarding = DaxOnboarding(settings: InMemoryDaxOnboardingSettings())

    override func setUp() {
        super.setUp()
    }

    func testWhenEachVersionOfTrackersMessageIsShownThenFormattedCorrectlyAndNotShownAgain() {

        // swiftlint:disable line_length
        let testCases = [
            (urls: [ URLs.google ], expected: DaxOnboarding.BrowsingSpec.withOneMajorTracker.format(args: "Google"), line: #line),
            (urls: [ URLs.google, URLs.amazon ], expected: DaxOnboarding.BrowsingSpec.withOneMajorTrackerAndOthers.format(args: "Google", 1), line: #line),
            
            // The order of trackers shouldn't matter, google should be first due to higher prevalence
            (urls: [ URLs.facebook, URLs.google ], expected: DaxOnboarding.BrowsingSpec.withTwoMajorTrackers.format(args: "Google", "Facebook"), line: #line),
            
            (urls: [ URLs.facebook, URLs.google, URLs.amazon ], expected: DaxOnboarding.BrowsingSpec.withTwoMajorTrackerAndOthers.format(args: "Google", "Facebook", 1), line: #line)
        ]
        // swiftlint:enable line_length

        testCases.forEach { testCase in
            
            let onboarding = DaxOnboarding(settings: InMemoryDaxOnboardingSettings())
            let siteRating = SiteRating(url: URLs.example)
            
            testCase.urls.forEach { url in
                
                let entity = TrackerDataManager.shared.findEntity(forHost: url.host!)
                let knownTracker = TrackerDataManager.shared.findTracker(forUrl: url.absoluteString)
                let tracker = DetectedTracker(url: url.absoluteString,
                                              knownTracker: knownTracker,
                                              entity: entity,
                                              blocked: true)
                
                siteRating.trackerDetected(tracker)
            }
            
            // Assert the expected case
            XCTAssertEqual(testCase.expected, onboarding.nextBrowsingMessage(siteRating: siteRating), file: #file, line: UInt(testCase.line))
            
            // Also assert the we don't see the message on subsequent calls
            XCTAssertNil(onboarding.nextBrowsingMessage(siteRating: siteRating), file: #file, line: UInt(testCase.line))
        }
        
    }

    func testWhenSecondTimeOnSiteThatIsOwnedByFacebookThenShowNothing() {
        let siteRating = SiteRating(url: URLs.ownedByFacebook)
        XCTAssertNotNil(onboarding.nextBrowsingMessage(siteRating: siteRating))
        XCTAssertNil(onboarding.nextBrowsingMessage(siteRating: siteRating))
    }

    func testWhenFirstTimeOnSiteThatIsOwnedByFacebookThenShowOwnedByMajorTrackingMessage() {
        let siteRating = SiteRating(url: URLs.ownedByFacebook)
        XCTAssertEqual(DaxOnboarding.BrowsingSpec.siteOwnedByMajorTracker.format(args: "instagram.com", "Facebook", 39.0),
                       onboarding.nextBrowsingMessage(siteRating: siteRating))
    }

    func testWhenSecondTimeOnSiteThatIsMajorTrackerThenShowNothing() {
        let siteRating = SiteRating(url: URLs.facebook)
        XCTAssertNotNil(onboarding.nextBrowsingMessage(siteRating: siteRating))
        XCTAssertNil(onboarding.nextBrowsingMessage(siteRating: siteRating))
    }

    func testWhenFirstTimeOnFacebookThenShowMajorTrackingMessage() {
        let siteRating = SiteRating(url: URLs.facebook)
        XCTAssertEqual(DaxOnboarding.BrowsingSpec.siteIsMajorTracker, onboarding.nextBrowsingMessage(siteRating: siteRating))
    }

    func testWhenFirstTimeOnGoogleThenShowMajorTrackingMessage() {
        let siteRating = SiteRating(url: URLs.google)
        XCTAssertEqual(DaxOnboarding.BrowsingSpec.siteIsMajorTracker, onboarding.nextBrowsingMessage(siteRating: siteRating))
    }

    func testWhenSecondTimeOnPageWithNoTrackersThenTrackersThenShowNothing() {
        let siteRating = SiteRating(url: URLs.example)
        XCTAssertNotNil(onboarding.nextBrowsingMessage(siteRating: siteRating))
        XCTAssertNil(onboarding.nextBrowsingMessage(siteRating: siteRating))
    }

    func testWhenFirstTimeOnPageWithNoTrackersThenTrackersThenShowNoTrackersMessage() {
        let siteRating = SiteRating(url: URLs.example)
        XCTAssertEqual(DaxOnboarding.BrowsingSpec.withoutTrackers, onboarding.nextBrowsingMessage(siteRating: siteRating))
    }
    
    func testWhenSecondTimeOnSearchPageThenShowNothing() {
        XCTAssertNotNil(onboarding.nextBrowsingMessage(siteRating: SiteRating(url: URLs.ddg)))
        XCTAssertNil(onboarding.nextBrowsingMessage(siteRating: SiteRating(url: URLs.ddg)))
    }
    
    func testWhenFirstTimeOnSearchPageThenShowSearchPageMessage() {
        XCTAssertEqual(DaxOnboarding.BrowsingSpec.afterSearch, onboarding.nextBrowsingMessage(siteRating: SiteRating(url: URLs.ddg)))
    }

    func testWhenDimissedThenShowNothing() {
        onboarding.dismiss()
        XCTAssertNil(onboarding.nextHomeScreenMessage())
        XCTAssertNil(onboarding.nextBrowsingMessage(siteRating: SiteRating(url: URLs.example)))
    }
    
    func testWhenThirdTimeOnHomeScreenAndAtLeastOneBrowsingDialogSeenThenShowNothing() {
        XCTAssertNotNil(onboarding.nextHomeScreenMessage())
        XCTAssertNotNil(onboarding.nextBrowsingMessage(siteRating: SiteRating(url: URLs.ddg)))
        XCTAssertEqual(DaxOnboarding.HomeScreenSpec.subsequent, onboarding.nextHomeScreenMessage())
        XCTAssertNil(onboarding.nextHomeScreenMessage())
    }

    func testWhenSecondTimeOnHomeScreenAndAtLeastOneBrowsingDialogSeenThenShowSubsequentDialog() {
        XCTAssertNotNil(onboarding.nextHomeScreenMessage())
        XCTAssertNotNil(onboarding.nextBrowsingMessage(siteRating: SiteRating(url: URLs.ddg)))
        XCTAssertEqual(DaxOnboarding.HomeScreenSpec.subsequent, onboarding.nextHomeScreenMessage())
    }

    func testWhenSecondTimeOnHomeScreenAndNoOtherDialgosSeenThenShowNothing() {
        XCTAssertNotNil(onboarding.nextHomeScreenMessage())
        XCTAssertNil(onboarding.nextHomeScreenMessage())
    }

    func testWhenFirstTimeOnHomeScreenThenShowFirstDialog() {
        XCTAssertEqual(DaxOnboarding.HomeScreenSpec.initial, onboarding.nextHomeScreenMessage())
    }
    
}