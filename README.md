# Discord Account Creator

Automates Discord account registration using a temporary email from [mail.cx](https://mail.cx).

## How it works

1. Opens mail.cx and grabs a temporary email address
2. Opens Discord's registration page and fills the form (email, display name, username, password, DOB)
3. Submits registration and polls the inbox for Discord's verification email
4. Opens the email inside mail.cx, extracts the **Verify Email** link, and opens it in a new tab
5. Loops: press **Enter** to create the next account, or type `x` and Enter to close

## Usage

```bash
npm install playwright
npx playwright install firefox
./vishal.sh
```

Display names are realistic Indian first names; usernames are derived from them
(lowercase, alphanumeric + `._`, 2-32 chars) so they look human.

Note: Discord rate-limits signups from a single IP — if no verification email
It arrives within 4 minutes. Please wait a while or change your IP, then try again.
