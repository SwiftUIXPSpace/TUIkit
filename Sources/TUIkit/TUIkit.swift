//  🖥️ TUIKit — Terminal UI Kit for Swift
//  TUIkit.swift
//
//  Created by LAYERED.work
//  License: MIT
//  TUIkit enables creating TUI applications with a declarative,
//  SwiftUI-like syntax - without ncurses or other low-level libraries.
//

import Foundation

/// The current version of TUIkit.
///
/// Read from `Sources/TUIkit/VERSION` (bundled as a resource).
/// Update the `VERSION` file to change the version number.
public let tuiKitVersion: String = {
    guard let url = Bundle.module.url(forResource: "VERSION", withExtension: nil),
          let content = try? String(contentsOf: url, encoding: .utf8)
    else {
        return "unknown"
    }
    return content.trimmingCharacters(in: .whitespacesAndNewlines)
}()

/// Executes a view closure and renders it once.
///
/// This is useful for simple CLI tools that don't need a full App.
///
/// # Example
///
/// ```swift
/// renderOnce {
///     VStack {
///         Text("Hello, TUIkit!")
///             .bold()
///             .foregroundStyle(.cyan)
///         Divider()
///         Text("Version \(tuiKitVersion)")
///             .dim()
///     }
/// }
/// ```
///
/// - Parameter content: A ViewBuilder closure that defines the view to render.
@MainActor
public func renderOnce<Content: View>(@ViewBuilder content: () -> Content) {
    let view = content()
    let renderer = ViewRenderer()
    renderer.render(view)
}

/// Requests a graceful shutdown of the running TUIkit application.
///
/// This function triggers a clean exit that allows TUIkit to:
/// - Restore the terminal to its original state
/// - Show the cursor
/// - Exit the alternate screen buffer
/// - Clean up any resources
///
/// Use this instead of calling `exit()` directly to ensure proper terminal cleanup.
///
/// # Example
///
/// ```swift
/// struct ContentView: View {
///     var body: some View {
///         Button("Quit") {
///             TUIkit.quit()
///         }
///     }
/// }
/// ```
///
/// - Note: This function can be called from any thread.
public func quit() {
    AppState.shared.requestShutdown()
}

// MARK: - Focus Management

/// Global focus manager instance shared across the application.
///
/// This is set by `AppRunner` when the app starts and can be used
/// to programmatically control focus from view code.
@MainActor
public var sharedFocusManager: FocusManager?

/// Requests focus for a specific element by ID.
///
/// Use this to programmatically focus an element (e.g., a TextField)
/// after a state change. The focus is applied at the end of the current render pass.
///
/// # Example
///
/// ```swift
/// struct ContentView: View {
///     @State var isProcessing = false
///
///     var body: some View {
///         if isProcessing {
///             Text("Processing...")
///         } else {
///             TextField("Input", text: $input)
///                 .focusID("input-field")
///         }
///     }
///
///     func finishProcessing() {
///         isProcessing = false
///         TUIkit.requestFocus(id: "input-field")
///     }
/// }
/// ```
///
/// - Parameter id: The focus ID of the element to focus.
@MainActor
public func requestFocus(id: String) {
    sharedFocusManager?.requestFocus(id: id)
}

/// Clears the current focus.
///
/// Call this to remove focus from all elements, allowing global
/// keyboard shortcuts to work.
@MainActor
public func clearFocus() {
    sharedFocusManager?.clearFocus()
}
