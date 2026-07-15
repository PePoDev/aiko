# Password Visibility Toggle Design

## Goal

Add a standard show/hide control to the password field on `LoginScreen`. The
field is shared by the Log In and Sign up actions, so the same behavior applies
to both flows.

## Interaction

- The password starts hidden whenever `LoginScreen` is created.
- A trailing eye button shows the password when tapped and hides it when tapped
  again.
- The button uses the tooltips `Show password` and `Hide password` so its
  current action is accessible.
- Toggling visibility does not change the password text, focus, or form action.
- The button is disabled while an authentication request is submitting, in
  line with the disabled password field.

## Implementation

Keep a private boolean in `_LoginScreenState`, initially set to hide the
password. Bind `TextField.obscureText` to that boolean and add an `IconButton`
to `InputDecoration.suffixIcon`. The icon and tooltip reflect the action the
button will perform. No reusable component or authentication-layer change is
needed because this is the only password field in the current UI.

## Testing

Add a focused widget test for `LoginScreen` that verifies:

1. The password is hidden initially and the show-password action is present.
2. Tapping the action reveals the existing password without clearing it.
3. The action changes to hide-password and a second tap hides the password.
4. The toggle is unavailable while submission is in progress.

Run the focused widget test, the complete Flutter test suite, and static
analysis before completion.

## Out of Scope

- New password validation rules.
- Changes to login, signup, reset-password, or OAuth behavior.
- A reusable password-field abstraction before another password field needs it.
