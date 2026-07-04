import Foundation

// Placeholder entry point.
//
// The executable target needs a `main` symbol to link. Once any file in the
// target imports AppKit, a clean `swift test` fails without one. This empty
// entry point satisfies the linker while the logic is built and unit-tested
// (Tasks 1–6). Task 7 replaces this file with the real NSApplication
// bootstrap. It is never executed until then.
