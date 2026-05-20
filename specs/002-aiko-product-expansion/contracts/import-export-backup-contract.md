# Contract: Import, Export, And Backup

## Import Contract

Supported source classes:

- CSV
- Excel
- OFX
- QIF
- bank statement
- credit card statement
- pasted table
- receipt OCR
- email receipt

Every import flow must define preview, field mapping, validation issues, duplicate candidates, user confirmation, saved result, failure state, and rollback behavior.

## Export Contract

Export scopes:

- transactions
- reports
- tax data
- portfolio data
- calculator scenarios
- full backup

Export formats are release-classified as CSV, PDF, Excel, JSON, image snapshot, or backup package.

## Backup Contract

Backup and restore must define encryption expectation, included scopes, restore preview, conflict behavior, failure state, and user-readable status.

## Sensitive Data Contract

Exports and backups containing AI, tax, investment, documents, or full account data must show scope and sensitivity warnings before generation.
