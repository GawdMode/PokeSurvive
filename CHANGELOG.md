# Changelog

## 0.18.21-rc.2

Release-candidate regression fixes.

- SURVIVE no longer crams damage and drain modifiers onto one Mood FX row.
  Miserable/Ecstatic use a separate MOOD DRAIN row.
- Battle permadeath resolves faint callbacks to unique save-party members,
  preventing duplicate `ran off` messages for one Pokemon.
- Full-party game over establishes a fresh field-HP baseline after Continue so
  the previous wipe cannot immediately replay its run-off messages/game over.
- Area-transition Adventure fallback is less aggressive:
  - second area: 20%
  - third area: 50%
  - fourth area: guaranteed if eligible
  Step-driven Adventure Event timing is unchanged.
- Trainer randomization was audited and confirmed to be per trainer roster and
  party slot, not a global vanilla-species replacement table.

## 0.18.21-rc.1

Public-alpha release-candidate cleanup.

- Removed development-only entries from the public SURVIVE menu.
- Retained internal legacy PokeSim save keys and palette identifiers.
- Added public-facing README, Known Issues, and Changelog documents.
- Removed editor/package placeholder files from the distributable mod.
- No gameplay balance or randomization behavior intentionally changed from
  v0.18.20.
