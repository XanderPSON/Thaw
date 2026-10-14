//
//  ItemPlacementURI.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation
import MenuBarModel

// MARK: - ItemPlacementRequest

/// A validated thaw://move-item request: one item identifier and the section it should land in.
struct ItemPlacementRequest: Equatable {
    let identifier: String
    let section: MenuBarSectionName

    enum ParseError: Error, Equatable {
        /// Neither or both of bundle and item-id were given.
        case needsExactlyOneOfBundleOrItemID
        /// The bundle matched no assigned item, or more than one.
        case bundleNotUnique
        case missingSection
        case unknownSection(String)
    }

    /// Turns the raw URL parameters into a request, using the same identifier rules as reveal-item.
    static func parse(
        bundle: String?,
        itemID: String?,
        section: String?,
        sectionAssignment: [String: MenuBarSectionName]
    ) -> Result<ItemPlacementRequest, ParseError> {
        let hasBundle = !(bundle?.isEmpty ?? true)
        let hasItemID = !(itemID?.isEmpty ?? true)
        guard hasBundle != hasItemID else { return .failure(.needsExactlyOneOfBundleOrItemID) }

        guard let section, !section.isEmpty else { return .failure(.missingSection) }
        guard let name = sectionName(section) else { return .failure(.unknownSection(section)) }

        guard let identifier = SettingsURIHandler.resolveRevealItemIdentifier(
            bundle: bundle,
            itemID: itemID,
            sectionAssignment: sectionAssignment
        ) else {
            return .failure(.bundleNotUnique)
        }
        return .success(ItemPlacementRequest(identifier: identifier, section: name))
    }

    /// The URL spells the third section with a hyphen; the enum's raw value is camel case.
    private static func sectionName(_ value: String) -> MenuBarSectionName? {
        switch value.lowercased() {
        case "visible": .visible
        case "hidden": .hidden
        case "always-hidden": .alwaysHidden
        default: nil
        }
    }
}

// MARK: - ItemPlacementURI

/// Carries out thaw://move-item by handing the matching item to the same move the Layout editor and search panel use.
@MainActor
enum ItemPlacementURI {
    static func handle(_ url: URL, sender: String?, appState: AppState) {
        let log = appState.diagLog
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        func value(_ name: String) -> String? {
            items?.first { $0.name == name }?.value
        }

        let controller = appState.menuBarManager.sectionController
        guard controller.isOperational else {
            log.warning("Settings URI move-item: moving items is unavailable on this OS")
            return
        }

        let request: ItemPlacementRequest
        switch ItemPlacementRequest.parse(
            bundle: value("bundle"),
            itemID: value("item-id"),
            section: value("section"),
            sectionAssignment: controller.sectionAssignment
        ) {
        case let .success(parsed):
            request = parsed
        case let .failure(error):
            log.warning("Settings URI move-item: \(error) in \(url.absoluteString)")
            return
        }

        let target = request.section
        guard MenuBarSearchItemActions.moveDestinations(appState: appState).contains(target) else {
            log.warning("Settings URI move-item: the \(target.displayString) section is turned off")
            return
        }
        guard let item = appState.itemManager.managedItems.first(where: {
            MenuBarItemTag.canonicalPersistentIdentifier($0.uniqueIdentifier) == request.identifier
        }) else {
            log.warning("Settings URI move-item: no managed item with identifier \(request.identifier)")
            return
        }
        guard MenuBarBackendProvider.current.canAssign(
            item,
            to: target,
            experimentalSystemItemHiding: appState.settings.advanced.enableExperimentalSystemItemHiding
        ) else {
            log.warning("Settings URI move-item: \(request.identifier) cannot be placed in the \(target.displayString) section")
            return
        }
        guard controller.section(for: item) != target else {
            log.info("Settings URI move-item: \(request.identifier) is already in the \(target.displayString) section")
            return
        }

        MenuBarSearchItemActions.move(item, to: target, appState: appState)
        log.info("Settings URI move-item: moving \(request.identifier) to the \(target.displayString) section for sender \(sender ?? "unknown")")
    }
}
