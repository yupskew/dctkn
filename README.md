<p align="center">
  <b style="font-size:2.5rem;">Discord Token Gen</b>
</p>
<p align="center">
  <i>Browser automation, taught by actually building something.</i>
</p>

<p align="center">
  <a href="https://mail.cx"><img alt="Educational" src="https://img.shields.io/badge/Purpose-Educational-8A2BE2?labelColor=0a0a0a"></a>
  <img alt="Node.js" src="https://img.shields.io/badge/Node.js-%3E%3D18-339933?logo=nodedotjs&logoColor=white&labelColor=0a0a0a">
  <img alt="Playwright" src="https://img.shields.io/badge/Playwright-Firefox-2EAD33?logo=playwright&logoColor=white&labelColor=0a0a0a">
  <img alt="Temp mail" src="https://img.shields.io/badge/Temp%20Mail-mail.cx-ff5722?labelColor=0a0a0a">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-yellow?labelColor=0a0a0a">
</p>

---

> ## This project is educational.
>
> Its purpose is to teach how real browsers work under automation — scraping,
> selectors, waiting, iframes, CLI loops — with a fun, working example. It is
> **not** a tool for creating accounts in bulk, and it never should be: that
> violates Discord's Terms of Service and gets accounts (and IPs) banned.
> **Learn from it. Don't abuse it.**

---

## The short version

`vishal.sh` is a Playwright bot that registers a Discord account end-to-end — and shows you exactly how it does it:

1. Mints a throwaway email on **mail.cx**
2. Fills Discord's signup form: email, name, username, password, DOB
3. Submits, waits for the verification email, opens it, clicks **Verify Email**
4. Prints the account (email / username / password / DOB), then asks: another one?

`Enter` = next account. `x` + `Enter` = done.

---

## Get it running

```bash
npm install playwright
npx playwright install firefox
./vishal.sh
```

Requirements: **Node.js ≥ 18** and a desktop OS. The bot drives a real, visible browser window — that's the whole point of learning to automate.

---

## The educational part (the good stuff)

This isn't a magic script. Every line below exists because real-world automation forces you to solve a real problem. Here are the ones worth stealing.

### 1. The browser is a scriptable app

Playwright starts a real Firefox and lets you type, click, wait, and read pages from code. A `context` is one browser *profile* — shared cookies and storage — which is why a mail.cx tab and a Discord tab can act like the same browser session.

```js
const browser = await firefox.launch({ headless: false });
const context = await browser.newContext();
```

### 2. When there's no API, the DOM is the API

mail.cx has no public inbox endpoint. So the email address is read straight off the rendered page, and the inbox is watched by polling the DOM. Scraping is a legitimate technique exactly when no official interface exists.

```js
const email = (await mailPage.locator('div.font-mono').first().innerText()).trim();
```

### 3. Custom dropdowns break the easy tools

Discord's Month / Day / Year fields are **not** `<select>` elements — they're hacked-together `role="combobox"` divs. Native select APIs fail against them. The reliable trick is keyboard *typeahead*: focus the box, type the value, press Enter.

```js
const combo = page.locator(`[role="combobox"][aria-label="Month"]`);
await combo.focus();
await page.keyboard.type('January');
await page.keyboard.press('Enter');
```

### 4. Overlayed elements intercept your clicks

An invisible hCaptcha iframe floats over the form and swallows pointer events. Two quiet workarounds: force the click, or flip the checkbox's state directly with `page.evaluate`.

```js
await page.evaluate(() => {
  const cb = document.querySelector('input[type="checkbox"]');
  if (cb && cb.checked) cb.click();
});
```

### 5. Wait for state, never guess

Blind `sleep()`s are how scripts grow flaky. The correct habit — polling until a condition is true:

```js
await mailPage.waitForFunction(
  () => [...document.querySelectorAll('div')]
    .some(d => d.className.includes('cursor-pointer') && d.textContent.trim().length > 10),
  null, { timeout: 240000 }
);
```

Debugging lesson baked in: these rows are clickable `<div>`s, **not** `<a>` links. A selector that assumed links found nothing, silently. Always inspect the real DOM before writing selectors.

### 6. The verify link hides inside an iframe

The email body renders in an iframe. Playwright can step into each frame and target the link **by its text** — `"Verify Email"` — because the email footer is full of near-identical marketing links.

```js
for (const f of mailPage.frames()) {
  const btn = f.locator('a').filter({ hasText: /verify email/i }).first();
}
```

### 7. The terminal drives the loop

The browser stays open while the terminal paces the work — a shared session, and a human stays in control:

```js
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
rl.question('> ', ans => { rl.close(); resolve(ans.trim()); });
```

---

## Files

```
discord/
├── vishal.sh      # the whole bot (bash wrapper + inline Node)
└── package.json   # just needs Playwright
```

## Honest limitations

- **Rate limiting is real, and that's the point.** Discord throttles signups from one IP — burst a few and verification emails dry up for a while. Waiting or switching IP is the only fix. There is deliberately no proxy spam built in.
- **Temp inboxes die after 1 hour.**
- **Captchas happen.** The bot pauses so you can solve them in the open window by hand.

---

## License

MIT. Build something, learn from it, and keep it pleasant.