# Discord Token Gen

A no-nonsense, Playwright-powered bot that signs up Discord accounts for you — fresh temp email, real-looking Indian display name, details filled, emailed verified — then hands you the account. One command, then just press **Enter** to go again.

> **Straight talk:** this is for learning browser automation. Making accounts in bulk breaks Discord's Terms of Service and can get accounts (and your IP) banned. Use it to learn — not to spam.

---

## The short version

1. It mints a throwaway email on **mail.cx**
2. It opens Discord's signup page and fills everything: email, name, username, password, DOB
3. It submits, waits for the verification email, opens it, and clicks **Verify Email** for you
4. It prints the account — email / username / password / DOB — and asks if you want another

And yes, it loops. Enter = next account. `x` + Enter = done.

---

## Get it running

```bash
npm install playwright
npx playwright install firefox
./vishal.sh
```

You need **Node.js** and a **desktop OS** — the bot drives a real, visible browser window so you can step in if Discord throws a captcha.

---

## How it actually works

Here's the honest, less-boring explanation.

### The browser is just another scriptable app

Playwright launches a real Firefox and lets you do by hand-and-eye everything: type, click, wait, read pages. One "profile" (a `context`) shares cookies across tabs, so the mail tab and the Discord tab feel like one browser.

### The temp email has no API — so the DOM is the API

mail.cx has no open inbox endpoint, so the bot reads the email address straight off the page and watches the inbox list for new mail. When there's no public API, scraping the rendered page is the legit fallback.

```js
const email = (await mailPage.locator('div.font-mono').first().innerText()).trim();
```

### Why Discord's date picker is annoying (and how to beat it)

Discord's Month/Day/Year are **not** real dropdowns. They're sneaky custom comboboxes, so standard select tools blow up on them. The trick: focus the box, type the first letters, hit Enter.

```js
const combo = page.locator(`[role="combobox"][aria-label="Month"]`);
await combo.focus();
await page.keyboard.type('January');
await page.keyboard.press('Enter');
```

### Things overlay and block clicks

An hCaptcha iframe floats over the signup box, so normal clicks get intercepted. Bypass it by forcing the click or toggling the checkbox via JavaScript:

```js
await page.evaluate(() => {
  const cb = document.querySelector('input[type="checkbox"]');
  if (cb && cb.checked) cb.click();
});
```

### Wait for things to happen — don't guess

Sleeping is fragile. The bot polls until it sees a new mail row (up to 4 minutes), then moves:

```js
await mailPage.waitForFunction(
  () => [...document.querySelectorAll('div')]
    .some(d => d.className.includes('cursor-pointer') && d.textContent.trim().length > 10),
  null, { timeout: 240000 }
);
```

Fun fact: these rows are clickable `<div>`s, **not** `<a>` links — a selector that assumed links would quietly find nothing. Check the real DOM before trusting your instincts.

### The verify link hides inside an iframe

The email body renders in an iframe. The bot steps into the frame and grabs the link **by its text** — `"Verify Email"` — not just "any link with discord", because the email footer is full of marketing links that look almost identical.

### The terminal drives the loop

The browser stays open while the terminal asks "another one?" between runs — so the whole session stays in one browser, and you stay in control.

---

## Files

```
discord/
├── vishal.sh      # the whole bot (bash wrapper + inline Node)
├── package.json   # just needs Playwright
└── CHANGELOG.md   # incremental dev log
```

## Be real about the limits

- **Rate limiting is not a bug to fix.** Discord slows down signups from one IP — burst a few accounts quickly and verification emails stop coming for a while. Wait it out or switch IP. There's intentionally no proxy spamming here.
- **Temp inboxes last 1 hour**, then vanish.
- **Captchas happen.** The bot pauses and lets you solve them in the open window.

---

## License

MIT. Learn something. Be cool.