#!/bin/bash
# vishal.sh - Automates Discord account registration using a temporary email from mail.cx
# Creates accounts in a loop: after one finishes, press Enter to make another,
# or type 'x' then Enter to close the browser and exit.

node <<'EOF'
const { firefox } = require('playwright');
const readline = require('readline');

const randNum = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];

const FIRST_NAMES = ['Arjun','Aarav','Vihaan','Reyansh','Ayaan','Advik','Aditya','Shaurya','Ansh','Kabir','Vivaan','Rohan','Dhruv','Ishaan','Kartik','Nikhil','Raj','Vikram','Amit','Deepak','Rajesh','Suresh','Pradeep','Manoj','Anil','Ravi','Sunil','Ajay','Vijay','Mohit','Kapil','Gaurav','Nitin','Tarun','Varun','Karan','Rahul','Akash','Aadhya','Ananya','Diya','Myra','Sara','Aarohi','Prisha','Kavya','Riya','Nisha','Pooja','Priya','Neha','Simran','Anita','Sunita','Meena','Geeta','Kavita','Deepika','Priyanka','Anjali','Kiran','Divya','Swati','Preeti','Manisha','Rekha','Usha','Asha','Jyoti','Savita','Sudha','Alka','Sarika','Reena','Tara','Soniya','Manju','Bharti','Pallavi','Shweta','Nandini','Madhuri','Sujata'];
const LAST_NAMES = ['Patel','Sharma','Kumar','Singh','Gupta','Reddy','Nair','Das','Bose','Banerjee','Chatterjee','Mukherjee','Iyer','Menon','Pillai','Rao','Verma','Mishra','Tiwari','Shukla','Pandey','Chauhan','Yadav','Jha','Sinha','Malhotra','Kapoor','Khanna','Chopra','Joshi','Bhat','Hegde','Kamath','Desai','Thakkar','Shah','Mehta','Bhatt','Aggarwal','Agarwal','Kaur','Gill','Dhillon','Sidhu','Sandhu','Oberoi','Khosla','Chandra','Bajaj','Saxena','Prasad','Krishna','Iyengar','Rathore','Choudhary','Solanki','Gohil','Goswami','Tandon','Khurana','Sehgal','Bhardwaj','Kulkarni','Deshpande','Naik','Rege','Vyas','Dubey','Trivedi','Tewari'];
const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];

const newIdentity = () => {
  const displayName = pick(FIRST_NAMES);
  const base = displayName.toLowerCase();
  const styles = [
    () => base,
    () => base + randNum(1, 9),
    () => base + '_' + randNum(10, 99),
    () => base + randNum(90, 2005),
    () => base + '_' + randNum(1994, 2004),
    () => base.slice(0, 6) + randNum(100, 999),
  ];
  const username = pick(styles)();
  const password = 'Op' + require('crypto').randomBytes(8).toString('hex') + '!23';
  const monthIdx = randNum(0, 11);
  const day = randNum(1, 28);
  const year = randNum(1990, 2003);
  return { displayName, username, password, monthIdx, day, year };
};

const ask = (promptText) => new Promise(resolve => {
  if (!process.stdin.isTTY) return resolve(null); // non-interactive: caller must just wait
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  rl.question(promptText + '\n> ', ans => { rl.close(); resolve(ans.trim()); });
});

async function createAccount(context) {
  const { displayName, username, password, monthIdx, day, year } = newIdentity();

  // ---------- Tab 1: Temp mail (mail.cx) ----------
  const mailPage = await context.newPage();
  await mailPage.goto('https://mail.cx', { waitUntil: 'domcontentloaded' });
  await mailPage.waitForSelector('div.font-mono', { timeout: 15000 });
  const email = (await mailPage.locator('div.font-mono').first().innerText()).trim();
  console.log('>> Temporary email:', email);

  // ---------- Tab 2: Discord register ----------
  const discordPage = await context.newPage();
  await discordPage.goto('https://discord.com/register', { waitUntil: 'domcontentloaded' });
  await discordPage.waitForSelector('input[name="email"]', { timeout: 20000 });

  await discordPage.locator('input[name="email"]').fill(email);
  await discordPage.locator('input[name="global_name"]').fill(displayName);
  await discordPage.locator('input[name="username"]').fill(username);
  await discordPage.locator('input[name="password"]').fill(password);

  // Date of birth (custom dropdowns - focus combobox, typeahead filter, Enter to select)
  const dPick = async (label, text) => {
    const combo = discordPage.locator(`[role="combobox"][aria-label="${label}"]`);
    await combo.focus();
    await discordPage.keyboard.type(text);
    await discordPage.waitForTimeout(400);
    await discordPage.keyboard.press('Enter');
  };
  await dPick('Month', MONTHS[monthIdx]);
  await dPick('Day', String(day));
  await dPick('Year', String(year));

  console.log('>> Display Name :', displayName);
  console.log('>> Username     :', username);
  console.log('>> Password     :', password);
  console.log('>> DOB          :', MONTHS[monthIdx], day, year);

  // Uncheck the "okay to send me emails" checkbox (hCaptcha overlay blocks pointer clicks, so toggle via DOM)
  await discordPage.evaluate(() => {
    const cb = document.querySelector('input[type="checkbox"]');
    if (cb && cb.checked) cb.click();
  });

  await discordPage.getByRole('button', { name: 'Create Account' }).click({ force: true, noWaitAfter: true });
  console.log('>> Registration submitted. If an hCaptcha challenge appears, solve it in the browser window.');
  console.log('>> Waiting for verification email...');

  // ---------- Poll mail.cx inbox for the Discord email ----------
  console.log('>> Polling inbox (up to 4 min)...');
  const gotMail = await mailPage.waitForFunction(
    () => {
      const card = [...document.querySelectorAll('div')].find(d => /shadow-\[0_8px/.test(d.className));
      if (!card) return false;
      return [...card.querySelectorAll('div')].some(d =>
        d.className.includes('cursor-pointer') && d.textContent.trim().length > 10);
    },
    null,
    { timeout: 240000 }
  ).catch(() => null);

  if (!gotMail) {
    const discordState = await discordPage.evaluate(() => document.body.innerText.slice(0, 400)).catch(() => 'n/a');
    console.log(`!! No mail within 4 min. Discord page says:\n${discordState}`);
    console.log('!! Likely causes: rate-limited (too many signups / same IP), phone verification required, or hCaptcha failed.');
    console.log('>> The Discord tab is still open - solve any captcha there, then continue.');
    return 'noMail';
  }
  console.log('>> Verification email received.');

  // ---------- 1) Open the Discord mail row inside mail.cx inbox ----------
  console.log('>> Opening the mail inside mail.cx...');
  await mailPage.waitForTimeout(1000);
  const clicked = await mailPage.evaluate(() => {
    const card = [...document.querySelectorAll('div')].find(d => /shadow-\[0_8px/.test(d.className));
    if (!card) return false;
    const rows = [...card.querySelectorAll('div.cursor-pointer')].filter(r => r.textContent.trim().length > 10);
    const target = rows.find(r => /verify|discord/i.test(r.textContent)) || rows[0];
    if (!target) return false;
    target.click();
    return true;
  });
  console.log('>> Mail row clicked:', clicked);
  await mailPage.waitForTimeout(5000);

  // ---------- 2) Extract the Discord verification link from the opened mail ----------
  // The mail renders inside an iframe on the mail detail page. Pick the "Verify Email" button link.
  let verifyUrl = null;
  let code = null;
  for (const f of mailPage.frames()) {
    const btn = f.locator('a').filter({ hasText: /verify email/i }).first();
    if (await btn.count().catch(() => 0)) {
      verifyUrl = await btn.getAttribute('href').catch(() => null);
      if (verifyUrl) break;
    }
  }
  if (!verifyUrl) {
    const payload = await mailPage.evaluate(() => {
      const raw = [...document.querySelectorAll('iframe')].map(f => f.src || f.srcdoc || ' ').join(' ');
      const links = [...document.querySelectorAll('a[href]')].map(a => a.href).concat(raw.match(/https?:\/\/\S+/g) || []);
      const v = links.find(u => /click\.discord\.com/.test(u) && /verify|upn=/i.test(u)) || null;
      const codeMatch = document.body.innerText.match(/\b\d{6}\b/);
      return { v, code: codeMatch ? codeMatch[0] : null };
    });
    verifyUrl = payload.v;
    code = payload.code;
  }
  console.log('>> Extracted verify link:', verifyUrl ? verifyUrl.slice(0, 90) + '...' : null, '| code:', code);

  // ---------- 3) Open the verification link/code in a separate tab ----------
  if (verifyUrl) {
    const verifyPage = await context.newPage();
    await verifyPage.goto(verifyUrl, { waitUntil: 'domcontentloaded' }).catch(e => console.log('!! verify page load:', e.message));
    console.log('>> Opened verification link in a NEW tab. Waiting for Discord to confirm...');
    await verifyPage.waitForTimeout(6000);
    const verified = await verifyPage.evaluate(() => {
      const t = document.body.innerText.slice(0, 600);
      return /verified|logged in|success/i.test(t);
    }).catch(() => false);
    console.log(verified ? '>> ACCOUNT VERIFIED.' : '>> Verify tab opened - check the browser (may show a login/captcha screen).');
    await verifyPage.close();
  } else if (code) {
    const codeInput = discordPage.locator('input[name="verify"]');
    if (await codeInput.count()) {
      await codeInput.fill(code);
      await discordPage.getByRole('button', { name: /verify|submit/i }).click().catch(() => {});
      console.log('>> Entered verification code in the Discord tab:', code);
    } else {
      console.log('>> Found code but no code input is shown on the Discord page yet:', code);
    }
  } else {
    console.log('>> No verify link/code extracted - open the mail manually and click "Verify Email".');
  }

  console.log('\n--- Account ---');
  console.log('Email     :', email);
  console.log('Username  :', username);
  console.log('Password  :', password);
  console.log('DOB       :', `${MONTHS[monthIdx]} ${day}, ${year}`);

  await mailPage.close();
  return 'ok';
}

(async () => {
  const browser = await firefox.launch({ headless: false });
  const context = await browser.newContext();

  let running = true;
  let round = 0;
  while (running) {
    round++;
    console.log(`\n========== Account #${round} ==========`);
    const result = await createAccount(context);

    if (result === 'noMail') {
      const ans = await ask('>> [Enter] retry a NEW account, or type x and Enter to close the browser');
      if (ans === null) await new Promise(() => {}); // non-interactive: wait forever
      if (/^x/i.test(ans || '')) running = false;
      continue;
    }

    const ans = await ask('>> Press Enter for ANOTHER account, or type x and Enter to close the browser');
    if (ans === null) await new Promise(() => {});   // non-interactive: never close on its own
    if (/^x/i.test(ans || '')) running = false;
  }

  await browser.close();
  console.log('>> Browser closed. Done.');
})();
EOF