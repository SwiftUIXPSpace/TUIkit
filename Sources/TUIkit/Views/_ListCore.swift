//  🖥️ TUIKit — Terminal UI Kit for Swift
//  _ListCore.swift
//
//  Created by LAYERED.work
//  License: MIT

// MARK: - List Core (Internal Rendering)

/// Internal core view that handles list rendering inside a ContainerView.
struct _ListCore<SelectionValue: Hashable & Sendable, Content: View, Footer: View>: View, Renderable, Layoutable {
    let title: String?
    let content: Content
    let footer: Footer?
    let singleSelection: Binding<SelectionValue?>?
    let multiSelection: Binding<Set<SelectionValue>>?
    let selectionMode: SelectionMode
    let focusID: String?
    let isDisabled: Bool
    let emptyPlaceholder: AnyView
    let showFooterSeparator: Bool

    /// When true, the list automatically scrolls to show the last item
    /// whenever new items are appended. Ideal for chat/log-style UIs.
    var scrollToBottom: Bool = false

    var body: Never {
        fatalError("_ListCore renders via Renderable")
    }

    // MARK: - Layoutable

    /// Reports the List's size requirements to parent layout containers.
    ///
    /// List is a greedy vertical component that should expand to fill available
    /// height. By reporting `isHeightFlexible = true` with a small minimum
    /// height, parent VStack can properly allocate remaining space after
    /// fixed-height siblings (e.g., Panel, TextField) have been measured.
    func sizeThatFits(proposal: ProposedSize, context: RenderContext) -> ViewSize {
        let style = context.environment.listStyle
        let borderOverhead = style.showsBorder ? 2 : 0
        let titleOverhead = title != nil ? 1 : 0
        let footerOverhead: Int = footer is EmptyView || footer == nil ? 0 : 2
        let minContentHeight = 1 // At least 1 row of content
        let minHeight = borderOverhead + titleOverhead + footerOverhead + minContentHeight

        // We do not calculate actualContentHeight here to avoid rendering all rows (performance)
        // and to prevent the list from requesting more height than the screen allows,
        // which would push other views off-screen and break scrolling logic.
        // The list will expand to fill available space due to isHeightFlexible = true.

        return ViewSize(
            width: context.availableWidth,
            height: minHeight,
            isWidthFlexible: true,
            isHeightFlexible: true
        )
    }

    // swiftlint:disable:next function_body_length
    func renderToBuffer(context: RenderContext) -> FrameBuffer {
        let palette = context.environment.palette
        let style = context.environment.listStyle
        let stateStorage = context.environment.stateStorage!

        // Extract rows from content
        let rows = extractRows(from: content, context: context)

        // Handle empty state
        let contentLines: [String]
        let listHasFocus: Bool

        if rows.isEmpty {
            // Render the placeholder view to a buffer
            let placeholderBuffer = TUIkit.renderToBuffer(emptyPlaceholder, context: context)
            let placeholderLines = placeholderBuffer.lines

            // Calculate target content area for centering
            let footerH = footer != nil ? 2 : 0
            let borderH = style.showsBorder ? 2 : 0
            let titleH = title != nil ? 1 : 0
            let targetH = max(1, context.availableHeight - borderH - titleH - footerH)
            let rowWidth: Int
            if context.hasExplicitWidth {
                let maxLineWidth = placeholderLines.map { $0.strippedLength }.max() ?? 0
                rowWidth = max(maxLineWidth, context.availableWidth - 2)
            } else {
                rowWidth = placeholderLines.map { $0.strippedLength }.max() ?? 0
            }

            // Center each placeholder line horizontally within rowWidth
            let centeredLines: [String] = placeholderLines.map { line in
                renderCenteredLine(line: line, rowWidth: rowWidth, backgroundColor: nil)
            }

            // Vertically center: add empty lines above and below
            let placeholderHeight = centeredLines.count
            let topPadding = max(0, (targetH - placeholderHeight) / 2)
            let bottomPadding = max(0, targetH - placeholderHeight - topPadding)

            var lines: [String] = []
            lines.append(contentsOf: Array(repeating: "", count: topPadding))
            lines.append(contentsOf: centeredLines)
            lines.append(contentsOf: Array(repeating: "", count: bottomPadding))
            contentLines = lines
            listHasFocus = false
        } else {
            // Calculate available space for content (rows + indicators) inside the container
            // We must calculate this BEFORE determining viewportHeight to ensure we don't
            // render more rows than can fit.
            let footerOverhead: Int = (footer is EmptyView || footer == nil) ? 0 : 2
            let borderOverhead = style.showsBorder ? 2 : 0
            let titleOverhead = title != nil ? 1 : 0
            let paddingOverhead = style.rowPadding.top + style.rowPadding.bottom
            let targetContentHeight = max(1, context.availableHeight - borderOverhead - titleOverhead - footerOverhead - paddingOverhead)

            // Get persistent handler to determine focus state for viewport calculation
            let handlerKey = StateStorage.StateKey(identity: context.identity, propertyIndex: 0)
            let handlerBox: StateBox<ItemListHandler<SelectionValue>> = stateStorage.storage(
                for: handlerKey,
                default: ItemListHandler(
                    focusID: FocusRegistration.persistFocusID(context: context, explicitFocusID: focusID, defaultPrefix: "list", propertyIndex: 1),
                    itemCount: scrollToBottom ? 0 : rows.count,
                    viewportHeight: 1, // Temporary, will be updated
                    selectionMode: selectionMode,
                    canBeFocused: !isDisabled
                )
            )
            let previousHandler = handlerBox.value
            
            // Determine target focus index
            var targetIndex = previousHandler.focusedIndex
            if scrollToBottom && rows.count > previousHandler.itemCount && rows.count > 0 {
                targetIndex = rows.count - 1
            }
            targetIndex = max(0, min(rows.count - 1, targetIndex))
            
            // Calculate adaptive viewport height (in items)
            // We count how many items fit in the available space, centered/anchored around targetIndex.
            // We reserve 2 lines for scroll indicators to be safe.
            let safeContentHeight = max(1, targetContentHeight - 2)
            var visibleItems = 0
            var usedHeight = 0
            
            // Count backwards from targetIndex
            for i in stride(from: targetIndex, through: 0, by: -1) {
                let h = rows[i].buffer.height
                if usedHeight + h > safeContentHeight { break }
                usedHeight += h
                visibleItems += 1
            }
            
            // If space remains, count forwards from targetIndex + 1
            if usedHeight < safeContentHeight {
                for i in (targetIndex + 1)..<rows.count {
                    let h = rows[i].buffer.height
                    if usedHeight + h > safeContentHeight { break }
                    usedHeight += h
                    visibleItems += 1
                }
            }
            
            // Use this as viewportHeight (in items) for the handler
            let viewportItemCount = max(1, visibleItems)

            let persistedFocusID = FocusRegistration.persistFocusID(
                context: context,
                explicitFocusID: focusID,
                defaultPrefix: "list",
                propertyIndex: 1  // focusID
            )
            
            // Reuse the handler box we already retrieved
            let handler = handlerBox.value
            
            // Capture previous item count before updating (for scroll-to-bottom detection)
            let previousItemCount = handler.itemCount
            
            // Update handler with current values
            handler.itemCount = rows.count
            handler.viewportHeight = viewportItemCount
            handler.canBeFocused = !isDisabled
            
            // Build selectableIndices set and itemIDs from typed rows
            var selectableIndices = Set<Int>()
            var itemIDs: [SelectionValue?] = []
            for (index, row) in rows.enumerated() {
                if let id = row.id {
                    // Content row: use actual ID
                    itemIDs.append(id)
                    selectableIndices.insert(index)
                } else {
                    // Header/footer: nil (non-selectable)
                    itemIDs.append(nil)
                }
            }
            handler.itemIDs = itemIDs
            handler.selectableIndices = selectableIndices
            
            // Assign selection bindings directly (type-safe, no AnyHashable conversion)
            handler.singleSelection = singleSelection
            handler.multiSelection = multiSelection
            
            // Auto-scroll to bottom when new items are appended (chat/log-style UIs).
            // Only triggers when itemCount increases, so the user can still scroll up
            // manually. The next time items are added, it will snap back to bottom.
            if scrollToBottom && rows.count > previousItemCount && rows.count > 0 {
                let lastSelectableIndex = selectableIndices.max() ?? (rows.count - 1)
                handler.focusedIndex = lastSelectableIndex
            }
            
            // Ensure focused item is visible
            handler.ensureFocusedItemVisible()
            
            FocusRegistration.register(context: context, handler: handler)
            listHasFocus = FocusRegistration.isFocused(context: context, focusID: persistedFocusID)
            
            // Calculate available height for rows (subtracting indicators if needed)
            let indicatorsHeight = (handler.hasContentAbove ? 1 : 0) + (handler.hasContentBelow ? 1 : 0)
            let renderViewportHeight = max(1, targetContentHeight - indicatorsHeight)
            
            // Calculate visible rows using line-based height
            let visibleRows = calculateVisibleRows(
                rows: rows,
                handler: handler,
                viewportHeight: renderViewportHeight
            )

            // Calculate row width based on the widest row content
            // If an explicit frame width is set, use the available width minus border padding
            let maxRowWidth = visibleRows.map { $0.row.buffer.width }.max() ?? 0
            let rowWidth: Int
            if context.hasExplicitWidth {
                // Use available width minus 2 for borders only (content padding is 0)
                rowWidth = max(maxRowWidth, context.availableWidth - 2)
            } else {
                rowWidth = maxRowWidth
            }

            // Build content lines
            var lines: [String] = []

            // Top scroll indicator
            if handler.hasContentAbove {
                lines.append(renderScrollIndicator(direction: .up, width: rowWidth, palette: palette))
            }

            // Render each visible row with alternating colors based on list style
            // Track section-relative content index for alternating colors
            var sectionContentIndex = 0
            for (rowIndex, row) in visibleRows {
                // Reset section content index on header
                if case .header = row.type {
                    sectionContentIndex = 0
                }

                let isFocused = handler.isFocused(at: rowIndex) && listHasFocus
                let isSelected = handler.isSelected(at: rowIndex)

                let styledLines = renderRow(
                    row: row,
                    isFocused: isFocused,
                    isSelected: isSelected,
                    rowWidth: rowWidth,
                    sectionContentIndex: sectionContentIndex,
                    style: style,
                    context: context,
                    palette: palette
                )
                lines.append(contentsOf: styledLines)

                // Increment section content index only for content rows
                if case .content = row.type {
                    sectionContentIndex += 1
                }
            }

            // Bottom scroll indicator
            if handler.hasContentBelow {
                lines.append(renderScrollIndicator(direction: .down, width: rowWidth, palette: palette))
            }

            contentLines = lines
        }

        // Pad content to fill available height (SwiftUI behavior: List is greedy)
        // Reserve space for: title line (1) + top border (1) + bottom border (1) + footer if present
        // Note: targetContentHeight is calculated above in the non-empty branch, but we recalculate here
        // to handle the empty branch case and keep scope clear.
        let footerHeight = (footer is EmptyView || footer == nil) ? 0 : 2
        let borderOverhead = style.showsBorder ? 2 : 0
        let titleOverhead = title != nil ? 1 : 0
        let paddingOverhead = style.rowPadding.top + style.rowPadding.bottom
        let targetContentHeight = max(1, context.availableHeight - borderOverhead - titleOverhead - footerHeight - paddingOverhead)

        var paddedContentLines = contentLines
        if paddedContentLines.count < targetContentHeight {
            let emptyLinesToAdd = targetContentHeight - paddedContentLines.count
            paddedContentLines.append(contentsOf: Array(repeating: "", count: emptyLinesToAdd))
        } else if paddedContentLines.count > targetContentHeight {
            // Clip content if it exceeds available height (prevent pushing other views out)
            paddedContentLines = Array(paddedContentLines.prefix(targetContentHeight))
        }

        // Create the list content as a simple view
        let listContent = _ListContentView(lines: paddedContentLines)

        // Render using the shared container helper with footer support
        // Apply list style: border from showsBorder, padding from style
        let config = ContainerConfig(
            borderStyle: style.showsBorder ? context.environment.appearance.borderStyle : nil,
            borderColor: style.showsBorder ? palette.border : nil,
            titleColor: nil,
            padding: style.rowPadding,
            showFooterSeparator: showFooterSeparator
        )

        return renderContainer(
            title: title,
            config: config,
            content: listContent,
            footer: footer,
            context: context
        )
    }

    // MARK: - Row Extraction

    private func extractRows(from content: Content, context: RenderContext) -> [SelectableListRow<SelectionValue>] {
        // Check for SectionRowExtractor first (Section view)
        // This must come before ChildInfoProvider because Section conforms to both
        if let section = content as? SectionRowExtractor {
            return extractSectionRows(from: section, context: context)
        }

        // Check for ListRowExtractor (ForEach)
        if let extractor = content as? ListRowExtractor {
            let rows: [ListRow<SelectionValue>] = extractor.extractListRows(context: context)
            return rows.map { SelectableListRow(type: .content(id: $0.id), buffer: $0.buffer, badge: $0.badge) }
        }

        // Check for ChildInfoProvider (handles TupleView with multiple children)
        if let provider = content as? ChildInfoProvider {
            return extractFromChildren(provider: provider, context: context)
        }

        // Fallback: render as single content row
        let buffer = TUIkit.renderToBuffer(content, context: context)
        if let zeroID = 0 as? SelectionValue {
            return [SelectableListRow(type: .content(id: zeroID), buffer: buffer)]
        }

        return []
    }

    /// Extracts rows from a ChildInfoProvider, handling Sections specially.
    private func extractFromChildren(
        provider: ChildInfoProvider,
        context: RenderContext
    ) -> [SelectableListRow<SelectionValue>] {
        var result: [SelectableListRow<SelectionValue>] = []
        let infos = provider.childInfos(context: context)

        for (index, info) in infos.enumerated() {
            guard let buffer = info.buffer else { continue }

            // Try to extract original view for Section detection
            // ChildInfo only has buffer, so we check the provider type
            if let indexID = index as? SelectionValue {
                result.append(SelectableListRow(type: .content(id: indexID), buffer: buffer))
            }
        }

        return result
    }

    /// Extracts typed rows from a Section (header + content + footer).
    private func extractSectionRows(
        from section: SectionRowExtractor,
        context: RenderContext
    ) -> [SelectableListRow<SelectionValue>] {
        var rows: [SelectableListRow<SelectionValue>] = []
        let info = section.extractSectionInfo(context: context)

        // Header (non-selectable)
        if let headerBuffer = info.headerBuffer {
            rows.append(SelectableListRow(type: .header, buffer: headerBuffer))
        }

        // Content rows (selectable)
        if let extractor = section as? ListRowExtractor {
            let contentRows: [ListRow<SelectionValue>] = extractor.extractListRows(context: context)
            for row in contentRows {
                rows.append(SelectableListRow(type: .content(id: row.id), buffer: row.buffer, badge: row.badge))
            }
        } else {
            // Fallback: render content as single row (if Section content is not ForEach)
            // Use the content buffer from SectionInfo
            // Note: This row is still selectable but uses index-based ID
            if !info.contentBuffer.lines.isEmpty, let indexID = 0 as? SelectionValue {
                rows.append(SelectableListRow(type: .content(id: indexID), buffer: info.contentBuffer))
            }
        }

        // Footer (non-selectable)
        if let footerBuffer = info.footerBuffer {
            rows.append(SelectableListRow(type: .footer, buffer: footerBuffer))
        }

        return rows
    }

    // MARK: - Visible Row Calculation

    private func calculateVisibleRows(
        rows: [SelectableListRow<SelectionValue>],
        handler: ItemListHandler<SelectionValue>,
        viewportHeight: Int
    ) -> [(index: Int, row: SelectableListRow<SelectionValue>)] {
        var result: [(Int, SelectableListRow<SelectionValue>)] = []
        var linesUsed = 0
        var currentIndex = handler.scrollOffset

        while currentIndex < rows.count && linesUsed < viewportHeight {
            let row = rows[currentIndex]
            let rowHeight = row.buffer.height

            if linesUsed + rowHeight <= viewportHeight {
                result.append((currentIndex, row))
                linesUsed += rowHeight
                currentIndex += 1
            } else {
                result.append((currentIndex, row))
                break
            }
        }

        return result
    }

    // MARK: - Row Rendering

    private func renderRow(
        row: SelectableListRow<SelectionValue>,
        isFocused: Bool,
        isSelected: Bool,
        rowWidth: Int,
        sectionContentIndex: Int,
        style: any ListStyle,
        context: RenderContext,
        palette: any Palette
    ) -> [String] {
        let backgroundColor = rowBackgroundColor(
            rowType: row.type,
            isFocused: isFocused,
            isSelected: isSelected,
            sectionContentIndex: sectionContentIndex,
            style: style,
            context: context,
            palette: palette
        )

        // Check for badge on the row (only for content rows, on first line only)
        let badge = row.badge
        let shouldRenderBadge = badge != nil && !badge!.isHidden && row.isSelectable

        // Render each line with padding and optional badge
        return row.buffer.lines.enumerated().map { lineIndex, line in
            if shouldRenderBadge && lineIndex == 0 {
                return renderLineWithBadge(
                    line: line, badge: badge!, rowWidth: rowWidth,
                    backgroundColor: backgroundColor, palette: palette
                )
            } else {
                return renderPlainLine(
                    line: line, rowWidth: rowWidth, backgroundColor: backgroundColor
                )
            }
        }
    }

    /// Determines the background color for a row based on its type and visual state.
    private func rowBackgroundColor(
        rowType: ListRowType<SelectionValue>,
        isFocused: Bool,
        isSelected: Bool,
        sectionContentIndex: Int,
        style: any ListStyle,
        context: RenderContext,
        palette: any Palette
    ) -> Color? {
        switch rowType {
        case .header, .footer:
            return nil

        case .content:
            if isFocused && isSelected {
                let dimAccent = palette.accent.opacity(ViewConstants.focusPulseMin)
                return Color.lerp(dimAccent, palette.accent.opacity(ViewConstants.focusPulseMax), phase: context.environment.pulsePhase)
            } else if isFocused {
                return palette.focusBackground
            } else if isSelected {
                return palette.accent.opacity(ViewConstants.selectedBackground)
            } else if style.alternatingRowColors && sectionContentIndex.isMultiple(of: 2) {
                return palette.accent.opacity(ViewConstants.alternatingRowBackground)
            } else {
                return nil
            }
        }
    }

    /// Renders a line with a right-aligned badge.
    /// Layout: [1 pad][content][fill padding][badge][1 pad]
    private func renderLineWithBadge(
        line: String,
        badge: BadgeValue,
        rowWidth: Int,
        backgroundColor: Color?,
        palette: any Palette
    ) -> String {
        let lineLength = line.strippedLength
        let badgeText = badge.displayText
        let styledBadge = ANSIRenderer.colorize(badgeText, foreground: palette.foregroundTertiary)

        let badgeWidth = badgeText.count
        let usedWidth = 1 + lineLength + badgeWidth + 1
        let fillPadding = max(1, rowWidth - usedWidth)
        let paddedLine = " " + line + String(repeating: " ", count: fillPadding) + styledBadge + " "

        return paddedLine.withPersistentBackground(backgroundColor)
    }

    /// Renders a plain line without badge.
    /// Layout: [1 pad][content][right padding]
    private func renderPlainLine(
        line: String,
        rowWidth: Int,
        backgroundColor: Color?
    ) -> String {
        let lineLength = line.strippedLength
        let usedWidth = 1 + lineLength
        let rightPadding = max(1, rowWidth - usedWidth)
        let paddedLine = " " + line + String(repeating: " ", count: rightPadding)

        return paddedLine.withPersistentBackground(backgroundColor)
    }

    /// Renders a line horizontally centered within the given rowWidth.
    /// Layout: [left padding][content][right padding]
    private func renderCenteredLine(
        line: String,
        rowWidth: Int,
        backgroundColor: Color?
    ) -> String {
        let lineLength = line.strippedLength
        let totalPadding = max(0, rowWidth - lineLength)
        let leftPad = totalPadding / 2
        let rightPad = totalPadding - leftPad
        let paddedLine = String(repeating: " ", count: leftPad) + line + String(repeating: " ", count: rightPad)

        if let bg = backgroundColor {
            return paddedLine.withPersistentBackground(bg)
        }
        return paddedLine
    }
}

// MARK: - List Content View

/// Simple view that renders pre-computed lines.
struct _ListContentView: View, Renderable {
    let lines: [String]

    var body: Never {
        fatalError("_ListContentView renders via Renderable")
    }

    func renderToBuffer(context: RenderContext) -> FrameBuffer {
        FrameBuffer(lines: lines)
    }
}
