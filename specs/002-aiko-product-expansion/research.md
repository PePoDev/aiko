# Research: Aiko Product Expansion Roadmap

## Decision: Keep Expansion In The Existing Flutter App

**Rationale**: The expansion features are user-facing mobile workflows that share navigation, theme, auth, storage, Aiko tone, and financial data with the existing MVP.

**Alternatives considered**: Separate apps or micro-frontends were rejected because they fragment user experience and duplicate financial state.

## Decision: Use Feature Slices Instead Of One Big Launch

**Rationale**: The product vision is broad. Each expansion area can deliver value independently and should be planned, tested, and released as a focused slice.

**Alternatives considered**: A single advanced-finance release was rejected because it would be too large to test, review, and explain to users.

## Decision: Treat External Providers As Contracts First

**Rationale**: Bank imports, OCR, investment prices, tax software, payments, and exchange rates are region/provider dependent. Planning contracts first avoids locking into vendors too early.

**Alternatives considered**: Selecting providers now was rejected because no country, pricing, compliance, or licensing requirements have been finalized.

## Decision: Progressive Disclosure Is Mandatory

**Rationale**: Aiko must support beginners and advanced users. Advanced finance, tax, portfolio, and business features must not overwhelm users who only need simple tracking.

**Alternatives considered**: Showing all modules in one dense More menu was rejected because it increases cognitive load and harms MVP clarity.

## Decision: Aiko Guidance Must Stay Explainable And Consent-Based

**Rationale**: Optimization, predictions, tax, investment, and debt suggestions can affect sensitive financial decisions. Users need source data, assumptions, uncertainty, controls, and disclaimers.

**Alternatives considered**: Fully automated AI advisor behavior was rejected for early expansion because it raises trust, compliance, and safety risks.

## Decision: Import/Export/Backup Are Trust Infrastructure

**Rationale**: Data portability, rollback, sensitive-data warnings, and recovery are foundational for broader product trust and monetization.

**Alternatives considered**: Delaying import/export until after advanced modules was rejected because advanced workflows depend on broader data entry and user confidence.

## Decision: Monetization Must Preserve Data Ownership

**Rationale**: Users must always be able to export data, delete accounts, see critical warnings, and access privacy controls regardless of plan.

**Alternatives considered**: Hard paywalls around data access were rejected because they conflict with privacy and trust principles.
