import XCTest

#if AGENT_DEVICE_RUNNER_UNIT_TESTS
extension RunnerTests {
  /// Every Apple return-key type this rule maps: the key's English wording, and the wire value the
  /// host publishes for it (design Feature C: `keyboard status` reports `returnKey`). The raw value
  /// is the contract, so these assert the pair, not the case alone. `Google`, `Yahoo` and
  /// `Emergency Call` are Apple types this rule leaves unmapped on purpose; the test below pins that.
  func testKeyboardReturnKeyKindNamesEachReturnKeyType() {
    let cases: [(label: String, expected: String)] = [
      ("Go", "go"),
      ("Search", "search"),
      ("Send", "send"),
      ("Next", "next"),
      ("Done", "done"),
      ("Join", "join"),
      ("Route", "route"),
      ("Continue", "continue"),
      ("Return", "enter"),
      ("Enter", "enter"),
    ]
    for (label, expected) in cases {
      XCTAssertEqual(RunnerKeyboardReturnKey.kind(of: label).rawValue, expected, label)
    }
  }

  /// Keyboards and iOS versions differ in the label's casing and padding; the kind it names does not.
  func testKeyboardReturnKeyKindIgnoresCasingAndPadding() {
    XCTAssertEqual(RunnerKeyboardReturnKey.kind(of: "done"), .done)
    XCTAssertEqual(RunnerKeyboardReturnKey.kind(of: "DONE"), .done)
    XCTAssertEqual(RunnerKeyboardReturnKey.kind(of: " Done"), .done)
    XCTAssertEqual(RunnerKeyboardReturnKey.kind(of: "\nSend\t"), .send)
  }

  /// The three Apple return-key types this rule leaves unmapped on purpose. `Google` and `Yahoo`
  /// name a vendor rather than a submit action, and `Emergency Call` places a call: reporting any of
  /// them as a submit kind would tell a caller to submit a field whose key does something else.
  func testKeyboardReturnKeyKindLeavesBrandedAndEmergencyAppleTypesUnknown() {
    for label in ["Google", "Yahoo", "Emergency Call"] {
      XCTAssertEqual(RunnerKeyboardReturnKey.kind(of: label), .unknown, label)
    }
  }

  /// Closest negatives: a label that CONTAINS a return-key word, or is a localized or custom key's
  /// wording, is not that key. A prefix or fuzzy rule would report a "Send Message" key as `send`,
  /// or a localized "Retour" key as `enter`; both would tell a caller to submit a field whose key
  /// does something else.
  func testKeyboardReturnKeyKindLeavesAmbiguousLabelsUnknown() {
    for label in [
      "Send Message",
      "Search Messages",
      "Done Sending",
      "Next slide",
      "Go to Settings",
      "Continued",
      "Return key",
      "Retour",
      "完了",
      "",
      "   ",
    ] {
      XCTAssertEqual(RunnerKeyboardReturnKey.kind(of: label), .unknown, label)
    }
  }

  /// The two owners of the key's wording stay aligned: every label the press path probes names a
  /// kind a status read can report, so a lookup that finds a control is never a status read that
  /// answers `unknown`.
  func testEveryKeyboardReturnProbeLabelMapsToAReportedKind() {
    let expected: [String: RunnerKeyboardReturnKey] = [
      "return": .enter,
      "Return": .enter,
      "Enter": .enter,
      "Go": .go,
      "Search": .search,
      "Next": .next,
      "Done": .done,
      "Send": .send,
      "Join": .join,
    ]
    for label in RunnerKeyboardReturnKey.probeLabels {
      XCTAssertEqual(RunnerKeyboardReturnKey.kind(of: label), expected[label], label)
    }
  }

  /// What a `keyboard status` read builds from each observation. The visible keyboard's return
  /// control decides both fields: its wording names the kind through the same rule `keyboard enter`
  /// probes with, and it is kept as the accessibility tree carries it apart from surrounding
  /// whitespace, so a key this read cannot name is still readable.
  func testKeyboardStatusReportsTheObservedReturnControl() {
    let status = RunnerKeyboardStatus.observed(visible: true, returnControlText: " Search ")
    XCTAssertEqual(status, RunnerKeyboardStatus(visible: true, returnKey: "search", returnKeyLabel: "Search"))
  }

  /// The kinds `kind(of:)` names but the press list never probes are reported by the read, because
  /// the read looks at the keyboard's own keys rather than looking a control up by English name.
  func testKeyboardStatusReportsAKindThePressProbeListOmits() {
    for (label, kind) in [("Route", "route"), ("Continue", "continue")] {
      XCTAssertEqual(
        RunnerKeyboardStatus.observed(visible: true, returnControlText: label),
        RunnerKeyboardStatus(visible: true, returnKey: kind, returnKeyLabel: label),
        label
      )
      XCTAssertFalse(
        RunnerKeyboardReturnKey.probeLabels.contains(label),
        "\(label) must stay out of the press probe list, which the read does not use"
      )
    }
  }

  /// A hidden keyboard reports no return key at all. That is a different fact from one it could not
  /// name, so both fields stay out rather than answering `unknown` for a key nobody can press. The
  /// keyboard's keys are ignored: nothing is being submitted to.
  func testKeyboardStatusReportsNoReturnKeyWhileTheKeyboardIsHidden() {
    XCTAssertEqual(
      RunnerKeyboardStatus.observed(visible: false, returnControlText: "Search"),
      RunnerKeyboardStatus(visible: false, returnKey: nil, returnKeyLabel: nil)
    )
    XCTAssertEqual(
      RunnerKeyboardStatus
        .observed(visible: false, keyboardKeys: [RunnerKeyboardStatus.ObservedKeyboardKey(text: "Done", frame: CGRect(x: 0, y: 0, width: 40, height: 40))]),
      RunnerKeyboardStatus(visible: false, returnKey: nil, returnKeyLabel: nil)
    )
  }

  /// The English keyboard, as the accessibility tree carries it: the search field's return key reads
  /// `Search` in the bottom-trailing slot. The picker names the kind from its wording.
  func testKeyboardStatusPicksTheReturnKeyFromTheKeyboardKeysByWording() {
    let keys = observedKeyboardKeysFixture([
      ("Q", 5, 959, 39), ("W", 44, 959, 40), ("shift", 5, 1067, 51), ("Delete", 348, 1067, 52),
      ("Numbers", 5, 1121, 49), ("Emoji", 54, 1121, 49), ("Space", 103, 1121, 197),
      ("Search", 301, 1121, 99), ("Padding-Right", 0, 952, 0),
    ])
    XCTAssertEqual(
      RunnerKeyboardStatus.observed(visible: true, keyboardKeys: keys),
      RunnerKeyboardStatus(visible: true, returnKey: "search", returnKeyLabel: "Search")
    )
  }

  /// The whole point of reading the keyboard's own keys: a fully localized keyboard names no kind, so
  /// the return key is the bottom-trailing control and its wording is reported even though the kind
  /// is `unknown`. These are the frames this read measured on a Polish iOS keyboard, where `szukaj`
  /// sits beside a wide space bar in the last row and the letter, shift and delete keys are higher or
  /// further left. The headless test IME, which exposes keys with no wording at all, is the same
  /// shape with nothing to report.
  func testKeyboardStatusReportsALocalizedReturnKeyWithItsOwnWording() {
    let keys = observedKeyboardKeysFixture([
      ("Padding-Left", 0, 952, 0), ("Q", 5, 959, 39), ("P", 360, 959, 40), ("shift", 5, 1067, 51),
      ("M", 301, 1067, 40), ("usuń", 348, 1067, 52), ("cyfry", 5, 1121, 49), ("Emoji", 54, 1121, 49),
      (" ", 103, 1121, 197), ("szukaj", 301, 1121, 99),
    ])
    XCTAssertEqual(
      RunnerKeyboardStatus.observed(visible: true, keyboardKeys: keys),
      RunnerKeyboardStatus(visible: true, returnKey: "unknown", returnKeyLabel: "szukaj")
    )
  }

  /// The picker takes a control whose wording names a kind even when another control sits further
  /// down-right, so a keyboard that localizes some keys and not others is still named by wording.
  /// Padding elements, which carry no usable frame, never win on position.
  func testKeyboardStatusPrefersNamedWordingOverKeyboardGeometry() {
    let keys = observedKeyboardKeysFixture([
      ("Done", 5, 959, 39), ("ż", 301, 1121, 99), ("Padding-Right", 0, 952, 0),
    ])
    XCTAssertEqual(
      RunnerKeyboardStatus.observed(visible: true, keyboardKeys: keys),
      RunnerKeyboardStatus(visible: true, returnKey: "done", returnKeyLabel: "Done")
    )
  }

  /// Only a visible keyboard that exposes no control worth reporting answers `unknown` with no label:
  /// an empty layout, a keyboard whose keys all carry no wording (a headless test IME), and one whose
  /// only wording sits on a zero-frame padding element.
  func testKeyboardStatusReportsUnknownForAVisibleKeyboardWithNoReadableKey() {
    let expected = RunnerKeyboardStatus(visible: true, returnKey: "unknown", returnKeyLabel: nil)
    XCTAssertEqual(RunnerKeyboardStatus.observed(visible: true, keyboardKeys: []), expected)
    XCTAssertEqual(
      RunnerKeyboardStatus.observed(
        visible: true,
        keyboardKeys: observedKeyboardKeysFixture([("   ", 301, 1121, 99)])
      ),
      expected
    )
    XCTAssertEqual(
      RunnerKeyboardStatus.observed(
        visible: true,
        keyboardKeys: observedKeyboardKeysFixture([("szukaj", 0, 952, 0)])
      ),
      expected
    )
  }

  /// The press path is unchanged by what the read can see: it still looks its own labels up in its
  /// own order, and the read never consults that list.
  func testKeyboardEnterProbeListStillOwnsItsOrder() {
    XCTAssertEqual(
      RunnerKeyboardReturnKey.probeLabels,
      ["return", "Return", "Enter", "Go", "Search", "Next", "Done", "Send", "Join"]
    )
  }

  /// A key whose wording the rule does not recognize keeps its wording, which is the whole point of
  /// reporting the label: a localized or a custom key stays readable where the kind is `unknown`.
  func testKeyboardStatusKeepsAnUnrecognizedLabelVerbatim() {
    for label in ["Send Message", "搜索", "完了"] {
      let status = RunnerKeyboardStatus.observed(visible: true, returnControlText: label)
      XCTAssertEqual(status.returnKey, "unknown", label)
      XCTAssertEqual(status.returnKeyLabel, label)
    }
  }

  /// Builds a keyboard's observed controls from the frames this read measured; a zero width is an
  /// element with no usable frame, such as the padding entries a keyboard exposes.
  private func observedKeyboardKeysFixture(
    _ entries: [(text: String, x: CGFloat, y: CGFloat, width: CGFloat)]
  ) -> [RunnerKeyboardStatus.ObservedKeyboardKey] {
    entries.map { entry in
      RunnerKeyboardStatus.ObservedKeyboardKey(
        text: entry.text,
        frame: CGRect(x: entry.x, y: entry.y, width: entry.width, height: entry.width > 0 ? 54 : 0)
      )
    }
  }
}
#endif
