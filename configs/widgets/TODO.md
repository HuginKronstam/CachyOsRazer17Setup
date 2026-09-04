# Custom widgets - TODO

## HuginWB

- **Theme styling needs further debugging.** Baseline colors/hover now use
  `PC3.ToolButton` + `Kirigami.Theme.colorSet: Kirigami.Theme.Button`
  instead of the original hand-rolled, unscoped `Kirigami.Theme.textColor`
  reference, and this fixed the reported white-icon/untethemed-hover issue -
  but it hasn't been stress-tested against the full range of global themes,
  only the one currently in use. Revisit if a future theme switch makes
  colors look wrong again.
- **Vertical panel orientation is unverified.** The sizing logic
  (`ButtonRow`'s horizontal-aware implicit size, `main.qml`'s
  `Layout.fillWidth`/`fillHeight` swap) was written to support it but never
  actually tested on a real vertical panel.
- **`TasksModelBridge` edge cases untested live**: multi-monitor setups
  (`filterByScreen`), virtual desktop switching, and the `AlwaysVisible`
  visibility policy's "show buttons for whatever was last active even with
  no window currently focused" behavior.
- **No config UI page exists yet** (deliberately deferred in v1 - that's
  exactly the feature surface that broke the old third-party applet).
  `visibilityPolicy` and the `override*Icon`/`override*Color` keys currently
  require `kwriteconfig6`. Worth adding a real settings page once the core
  is proven stable for a while.
- Button size/order customization beyond the fixed 3-button
  minimize/maximize/close set was explicitly a nice-to-have, not
  implemented.
- No validation on `override*Color` values - a malformed hex string would
  just be passed straight through to `Kirigami.Icon.color` as-is.

## Other

- The two bugs found and root-caused in the old `plasma-applet-window-buttons`
  (org.kde.windowbuttons) package are tracked for filing in `UPSTREAM-BUGS.md`
  at the repo root, not duplicated here.
