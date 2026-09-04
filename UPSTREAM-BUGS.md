# Upstream bugs to report

Bugs found while using this setup that are worth reporting upstream, batched
here instead of filing one-off as each is found. Move an entry to "Filed" once
it's been reported, with a link to the report.

## To file / follow up

- **KAddressBook: editing existing contacts fails (Google-synced contacts).**
  Matches already-open upstream bug
  [bugs.kde.org #492335](https://bugs.kde.org/show_bug.cgi?id=492335)
  ("Cannot Modify Contacts") - open since Aug 2024, still unresolved.
  Symptom: editing an existing contact reverts the change after a few
  seconds, or throws "Location was not saved"; console shows `Don't know how
  to handle metatype KAddressBookGrantlee::ContactGrantleeWrapper`. Adding
  new contacts works fine.
  What we found that isn't in the thread yet: reproduced specifically on a
  contact synced via `akonadi_google_resource` (Google Contacts); moving the
  contact to the local `akonadi_contacts_resource` backend fixed it. The
  existing thread only speculates about DAV/LDAP as possibly read-only - this
  adds Google as a confirmed trigger and backend type as the likely axis,
  not something specific to DAV/LDAP.
  **Action**: add a comment to #492335 with this repro detail.

- **`plasma-applet-window-buttons` (org.kde.windowbuttons) config UI bugs.**
  Found while building the replacement `HuginWB` plasmoid (see
  `configs/widgets/TODO.md`). Two separate bugs in its custom decoration/color
  override config page:
  1. Fatal QML crash (`Cannot override FINAL property`) - an old-style `Item`
     root config page conflicts with modern Kirigami's `PageRow`, which
     reserves `title` as `FINAL`.
  2. Broken custom `ComboBox` delegate in `DecorationsComboBox.qml` and
     `ColorsComboBox.qml` - dropdown row text renders invisible. Reproduced
     independent of theme (stock Breeze too) and independent of custom vs.
     Qt's default delegate.
  No newer upstream build exists (cachyos-extra and official extra ship the
  same broken version). Low priority since we've moved off this package
  entirely (see `HuginWB`), but worth filing to help other users who hit it.

## Filed

(none yet)
