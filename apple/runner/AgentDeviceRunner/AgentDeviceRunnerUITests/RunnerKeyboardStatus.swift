import Foundation
import CoreGraphics

/// One `keyboard status` answer: whether the software keyboard is on screen and, when it is, what
/// its return key offers.
///
/// `returnKey` is a `RunnerKeyboardReturnKey` raw value, or `nil` when the keyboard is hidden — a
/// hidden keyboard has no return key to report, which is a different fact from one this read cannot
/// name. `returnKeyLabel` is the wording the key itself carries, with surrounding whitespace
/// trimmed, so a localized or an app's custom key stays readable even where the kind is `unknown`.
/// It is present only when the read saw a key to read it from; a keyboard that exposes no readable
/// key answers `unknown` with no label.
struct RunnerKeyboardStatus: Equatable {
  let visible: Bool
  let returnKey: String?
  let returnKeyLabel: String?
}

extension RunnerKeyboardStatus {
  /// One control the status read observed on the visible keyboard: the wording it carries in the
  /// accessibility tree, and the frame it occupies. `frame` decides which control is the
  /// keyboard's bottom-trailing key, which is where Apple's keyboards place the return key.
  struct ObservedKeyboardKey {
    let text: String?
    let frame: CGRect
  }

  /// Builds the answer from what the runner observed. The keyboard decides whether a return key is
  /// reported at all: a hidden one has none, which is a different fact from one this read cannot
  /// name. Only Android's `IME_ACTION_NONE` can establish that a field offers no action key, so
  /// `none` is never this runner's answer.
  ///
  /// The key's own wording decides the kind, through the one rule `keyboard enter` probes with
  /// (`RunnerKeyboardReturnKey.kind(of:)`), so the two commands can never disagree about the same
  /// key. The label itself is kept as the accessibility tree carries it apart from its surrounding
  /// whitespace, so a localized or an app's custom key stays readable even where the kind is
  /// `unknown`.
  static func observed(
    visible: Bool,
    returnControlText: String?
  ) -> RunnerKeyboardStatus {
    guard visible else {
      return RunnerKeyboardStatus(visible: false, returnKey: nil, returnKeyLabel: nil)
    }
    guard let returnControlText else {
      return RunnerKeyboardStatus(
        visible: true,
        returnKey: RunnerKeyboardReturnKey.unknown.rawValue,
        returnKeyLabel: nil
      )
    }
    let label = returnControlText.trimmingCharacters(in: .whitespacesAndNewlines)
    return RunnerKeyboardStatus(
      visible: true,
      returnKey: RunnerKeyboardReturnKey.kind(of: label).rawValue,
      returnKeyLabel: label.isEmpty ? nil : label
    )
  }

  /// Builds the answer from every control the read saw on the visible keyboard, so it does not need to
  /// read English to find the return key. A control whose wording `kind(of:)` names a kind for is the
  /// return key on any keyboard in any language, and its wording is the label. When none maps — a
  /// fully localized keyboard — the return key is the measurable control in the keyboard's
  /// bottom-trailing corner: the slot Apple's keyboards give it, beside and right of the space bar,
  /// which no letter, shift or delete key reaches. A keyboard's padding elements report an empty
  /// frame and never win on position. An unmatched key's wording is still reported, with kind
  /// `unknown`: that is what the label is for. Only a keyboard exposing no worded, measurable control
  /// answers `unknown` with no label.
  static func observed(
    visible: Bool,
    keyboardKeys: [ObservedKeyboardKey]
  ) -> RunnerKeyboardStatus {
    guard visible else {
      return RunnerKeyboardStatus(visible: false, returnKey: nil, returnKeyLabel: nil)
    }
    let worded = keyboardKeys.filter { key in
      !(key.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    if let named = worded.first(where: { RunnerKeyboardReturnKey.kind(of: $0.text ?? "") != .unknown }) {
      return observed(visible: true, returnControlText: named.text)
    }
    let returnKey = worded
      .filter { !$0.frame.isEmpty }
      .max { lhs, rhs in (lhs.frame.maxY, lhs.frame.maxX) < (rhs.frame.maxY, rhs.frame.maxX) }
    return observed(visible: true, returnControlText: returnKey?.text)
  }
}
