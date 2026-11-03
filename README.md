# SEN Volunteer Gifts

A thank-you gift site for volunteers. Volunteers open a personal link, pick one gift, and enter a shipping address.
The admin dashboard shows every response so gifts can be bought on Amazon and tracked.

## Two versions live here
- **Email version (the one in use): `gifts/index.html`.** One shared link. Each response is emailed to the address in `SEND_TO` (via FormSubmit.co, no account). Gifts are a list at the top of that file.
- **Database version (parked): `index.html?t=...` + `admin/` + `schema.sql`.** Personal links and a dashboard. Admin sign-in was not finished.

## How the database version fits together
- `index.html`        the volunteer pages (gift choice, address form, confirmation). URL: `/?t=<personal token>`
- `admin/index.html`  the private dashboard (sign in with an emailed link)
- `config.js`         the database address + public key (safe to be public)
- `styles.css`        volunteer-page styling
- `schema.sql`        the database setup (run once in Supabase > SQL Editor)
- `images/`           logo and the starter gift photos

## Where the data lives
In a Supabase database. Privacy is enforced by the database itself (row-level security):
- Only emails listed in the `admins` table can read or change anything directly.
- Volunteers can only use two safe functions, `get_invitation` and `claim_gift`, and only with their own secret token.
- Volunteers never receive prices, Amazon links, or anyone else's information.
- One claim per invitation (database-enforced).

## Everyday tasks (all in the dashboard)
- Add / edit gifts: Gifts tab. Photos can be uploaded.
- New campaign: "New campaign" (can copy the gifts from another campaign). Campaigns start as Draft; set to Open in the Campaign tab.
- Add volunteers: Volunteers tab, paste "Name, email" lines. Copy their link or open a ready-made email.
- Fulfil: Responses tab, click a row, "View on Amazon", "Copy address", then mark Ordered / Completed.
- Privacy cleanup: "Delete this person's address", or "Delete all addresses" in the Campaign tab.
- Add another admin: in Supabase SQL Editor run `insert into public.admins (email) values ('name@example.com');`

## Rules for anyone editing this with Claude
- Never put a Supabase "service_role" or secret key in this repo. The public/publishable key in `config.js` is fine.
- Don't log addresses or put personal data in URLs. The only thing in a URL is the random token.
- Keep the Amazon purchase manual. Do not automate purchases or collect payment details.
- Hosted as static files on GitHub Pages; there is no server to maintain.
