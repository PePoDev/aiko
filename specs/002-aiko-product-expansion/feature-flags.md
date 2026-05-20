# Aiko Product Expansion Feature Flags

The expansion roadmap ships behind progressive-disclosure flags so MVP users keep a focused experience while advanced users can opt into broader finance tools.

## Defaults

| Flag | Default | Visibility |
| --- | --- | --- |
| `aikoCharacterControls` | on | Settings, onboarding |
| `importExportBackup` | on | Settings, More |
| `billsSubscriptions` | on | More, Insights |
| `creditDebt` | off | More, advanced finance |
| `portfolioAssets` | off | More, advanced finance |
| `taxAccounting` | off | More, advanced finance |
| `learningHub` | on | More, Aiko |
| `travelMode` | off | Settings, accounts |
| `deviceSync` | on | Settings, security |
| `aikoOptimize` | off | Aiko, Insights |
| `monetization` | off | Settings |

## Progressive Disclosure Rules

- Keep P1 modules discoverable in Settings or More without changing the MVP bottom navigation.
- Gate P2 and P3 modules behind explicit user intent, premium eligibility, or advanced-mode settings.
- Show disclaimers before tax, investment, debt optimization, or prediction output.
- Allow users to hide or reduce Aiko character visuals without disabling AI insights.
- Prefer placeholder routes with clear locked/coming-soon states until each feature slice is complete.
