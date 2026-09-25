# Changelog

All notable changes to SertantAI Compliance are recorded here, written for the
people who use it. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/) (0.x while the
product is in early release).

Add entries under **Unreleased** as work lands; `scripts/release.sh` turns them
into a versioned section. See `docs/RELEASING.md`.

## [Unreleased]

### Added

- **Applicability screener.** Describe your organisation once and see which UK
  laws apply to you, with confidence tiers (strong, probable, possible) and a
  plain explanation of why each law matched.
- **Organisation profile wizard.** A guided questionnaire for your roles,
  locations, materials, activities, sector and regions, with legal definitions
  on hover and conditional questions that are now saved.
- **Law drill-down.** For each matching law, see its provisions grouped by
  duties, rights, responsibilities and powers, and the applicability tree
  showing which of your answers matched.
- **Caveats for review.** When a law may not apply, for example it excludes an
  activity you do alongside others, or its dates look inconsistent, it is kept
  in your results with a "Check before accepting" note instead of being
  silently dropped. You decide.
- **Change feed.** Laws in your register that are amended, partly revoked or
  revoked are flagged with the amending or revoking law, a materiality level
  and a review due date. New laws that apply to you are flagged too. Checks
  run daily.
- **CSV export of changes**, to hand off into your own assessment tool.
- **Legal glossary.** Searchable legal definitions with citations and ready-made
  views.
- **Law browser.** Browse the UK legal register, working offline once loaded.
- **Profile API.** Read, replace or partially update your screening profile,
  check it against the screening vocabulary without saving, and see every code
  the screener understands. It is designed so AI assistants can work with it.

### Changed

- The screener now **prefers inclusion**: a law is only excluded for a
  categorical reason (revoked in full; legislation for a UK nation you don't
  operate in; or you are wholly within its exclusions). Anything less certain
  is shown with a caveat.
- Legislation made for Northern Ireland, Scotland or Wales is no longer
  suggested to organisations that don't operate there.

### Fixed

- Roles entered in your profile (for example "Employer") now match laws. Before,
  most role labels never matched.
- Place types such as premises, ships and aircraft are now matched correctly.
- Saving the profile wizard no longer clears certifications, contract
  requirements or conditions set elsewhere.

### Security

- Updated the Ash framework to address a published advisory.
