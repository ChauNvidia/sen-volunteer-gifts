# SEN gift form -> email (Google Apps Script)

`Code.gs` receives the website's form and emails each response. It runs under SEN's Google account, so volunteers'
confirmation emails come from SEN. No data is stored anywhere; the email is the record.

## One-time setup (signed in to the SEN Google account)
1. Go to https://script.google.com and click **New project**.
2. Delete the sample code and paste in all of `Code.gs`. Set `CONFIG.TO` to the inbox that should receive responses.
3. Click **Deploy > New deployment**, the gear icon > **Web app**. Execute as: **Me**. Who has access: **Anyone**. Click **Deploy**.
4. Approve the permissions when asked (it needs to send email as the account). Google may say "unverified app": click **Advanced**, then **Go to (project name)**.
5. Copy the **Web app URL** (ends in `/exec`) and set `FORM_URL` in `index.html` to it.

## Changing the script later
Edits don't go live until you click **Deploy > Manage deployments > edit (pencil) > Version: New version > Deploy**.
The web address stays the same.

## Limits and safety
- Google allows 1,500 emails/day on Workspace (100/day on a free Gmail account).
- Server-side checks on every field, a hidden spam-trap field, a per-hour cap, and a 6-hour duplicate guard.
- Never put personal email addresses in this public repo. Set `CONFIG.TO` only inside the Google script editor.
