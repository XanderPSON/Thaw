//
//  ItemPlacementRequestTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import MenuBarModel
import Testing
@testable import Thaw

@MainActor
@Suite("thaw://move-item request parsing")
struct ItemPlacementRequestTests {
    private let assignment: [String: MenuBarSectionName] = [
        "com.example.solo:Item-0": .hidden,
        "com.example.twin:Item-0": .visible,
        "com.example.twin:Item-1": .hidden,
    ]

    private func parse(
        bundle: String? = nil,
        itemID: String? = nil,
        section: String? = "hidden"
    ) -> Result<ItemPlacementRequest, ItemPlacementRequest.ParseError> {
        ItemPlacementRequest.parse(bundle: bundle, itemID: itemID, section: section, sectionAssignment: assignment)
    }

    @Test("A bundle with one assigned item resolves to that item")
    func validBundle() {
        #expect(
            parse(bundle: "com.example.solo", section: "always-hidden")
                == .success(.init(identifier: "com.example.solo:Item-0", section: .alwaysHidden))
        )
    }

    @Test("An item-id is used as given and each section spelling is accepted")
    func validItemID() {
        #expect(
            parse(itemID: "com.example.any:Item-3", section: "visible")
                == .success(.init(identifier: "com.example.any:Item-3", section: .visible))
        )
        #expect(parse(itemID: "com.example.any:Item-3", section: "hidden")
            == .success(.init(identifier: "com.example.any:Item-3", section: .hidden)))
    }

    @Test("Exactly one of bundle and item-id is required")
    func bundleXorItemID() {
        #expect(parse() == .failure(.needsExactlyOneOfBundleOrItemID))
        #expect(parse(bundle: "com.example.solo", itemID: "com.example.solo:Item-0")
            == .failure(.needsExactlyOneOfBundleOrItemID))
        #expect(parse(bundle: "") == .failure(.needsExactlyOneOfBundleOrItemID))
    }

    @Test("A missing or unknown section is rejected")
    func badSection() {
        #expect(parse(bundle: "com.example.solo", section: nil) == .failure(.missingSection))
        #expect(parse(bundle: "com.example.solo", section: "") == .failure(.missingSection))
        #expect(parse(bundle: "com.example.solo", section: "alwaysHidden") == .failure(.unknownSection("alwaysHidden")))
        #expect(parse(bundle: "com.example.solo", section: "nowhere") == .failure(.unknownSection("nowhere")))
    }

    @Test("A bundle with several items, or none, is refused")
    func bundleMustBeUnique() {
        #expect(parse(bundle: "com.example.twin") == .failure(.bundleNotUnique))
        #expect(parse(bundle: "com.example.missing") == .failure(.bundleNotUnique))
    }
}
