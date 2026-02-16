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
    RenderNotifier.current.requestShutdown()
}
