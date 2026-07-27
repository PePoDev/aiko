# Learning Hub Inline Glossary Design

## Goal

Remove the standalone Glossary card from the Learning Hub and place definitions
next to the learning content they explain. Known financial terms should look
interactive and reveal a compact definition tooltip without navigating away
from the page.

## Scope

- Remove the visible `Glossary` section.
- Keep glossary terms and definitions as reusable content data.
- Detect known terms in rendered lesson and quiz copy.
- Add the current glossary terms naturally to relevant learning content:
  - `Safe-to-spend` in the budgeting lesson.
  - `APR` in the credit lesson.
  - `Rebalancing` in a short new investing lesson.
- Support future glossary entries without manually wiring each occurrence.

Dashboard, reporting, calculator, and non-Learning-Hub text are out of scope.

## Interaction Design

Glossary terms render inline with the surrounding sentence. A subtle dotted
underline and the existing Learning Hub accent color indicate that the term is
interactive without overpowering the lesson text.

On touch devices, tapping or long-pressing a marked term opens a small tooltip
near that term. Pointer hover and keyboard focus expose the same definition on
supported devices. The tooltip uses the app theme, remains readable in light
and dark modes, and dismisses through normal tooltip behavior.

The term remains part of the sentence rather than becoming a separate chip,
icon, or row. This preserves reading flow and makes the definition available at
the moment it is useful.

## Architecture

Create a private, reusable inline glossary text widget within the Learning Hub
feature. It accepts:

- The source text.
- The normal text style and optional alignment/line limits.
- The glossary term-to-definition data.

The widget parses source text case-insensitively, matches complete terms, and
renders ordinary text plus interactive glossary spans. Longer terms are matched
before shorter terms so future overlapping entries behave predictably. The
visible text preserves its original capitalization.

Each matched term is wrapped in a themed tooltip target with an accessible
semantic label that includes both the term and its definition. Unmatched text
continues to render as normal text.

The existing glossary records remain the single source of truth. Adding a
future glossary entry and using that term in lesson or quiz copy is sufficient
for automatic tooltip behavior.

## Learning Content Changes

- Revise the budgeting summary to mention safe-to-spend naturally.
- Revise the credit summary to mention APR naturally.
- Add a concise `Rebalancing your portfolio` lesson in the Investing category,
  including one quiz question consistent with the existing lesson records.
- Use the inline glossary widget for rendered lesson titles, summaries, and
  rendered quiz copy.

The existing lesson progress presentation and quiz counts remain unchanged.

## Testing

Widget tests will verify:

1. The Learning Hub no longer renders a `Glossary` section.
2. All three current glossary terms appear in relevant lesson content.
3. Tapping or long-pressing a marked term displays its definition.
4. Ordinary text remains visible and unmarked.
5. Future glossary entries are matched automatically by the reusable widget.

The focused widget tests run first through a red-green cycle. Static analysis
and the complete Flutter test suite provide final verification.

## Accessibility and Error Handling

Terms use semantic labels and sufficiently distinct decoration rather than
color alone. Tooltip definitions are plain text and do not require navigation.
If a lesson contains no known terms, the widget renders the original text
unchanged. Empty source text and an empty glossary are valid inputs.
