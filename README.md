# SEN Volunteer Gifts

A thank-you gift site for volunteers. One shared link: a volunteer picks a gift, enters a shipping address, and the response is emailed to SEN.

## How it works (the version in use)
- `index.html`   the whole volunteer page. The gift list is at the top of the file.
- The form posts to a small Google Apps Script (see `apps-script/`), which emails the response to SEN and sends the volunteer a confirmation. The script keeps no list of volunteers.
- The real "send to" address lives only in a private copy of the script, kept outside this repo. The copy in `apps-script/` has a placeholder.

## Parked database version (removed from the live site)
An earlier version used a Supabase database with personal links and an admin dashboard. The `admin/` and `db/` pages were removed from the live site on Nov 4, 2026 because they were unused. They are still in the git history (last present at commit `d080c1b`). `schema.sql` and `config.js` are kept for reference.

## Files
- `index.html`    the volunteer page
- `styles.css`    page styling
- `images/`       logo, thank-you card, gift photos
- `apps-script/`  the email script (placeholder address) and setup notes
- `CNAME`         the custom domain (thanks.scholarsequity.org)

## Rules for anyone editing this with Claude
- Never put a secret key or a real personal email address in this repo. It is public.
- Don't log addresses or put personal data in URLs.
- Keep the Amazon purchase manual. Do not automate purchases or collect payment details.
- Hosted as static files on GitHub Pages; there is no server to maintain.
