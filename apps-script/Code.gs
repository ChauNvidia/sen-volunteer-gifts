/**
 * SEN gift form -> email.
 * Receives a volunteer's gift choice from the website and emails it to SEN.
 * Runs on Google, under the Google account that deploys it. No data is stored.
 *
 * SET THESE THREE LINES, then deploy as a Web app (see README.md in this folder).
 */
const CONFIG = {
  TO: "REPLACE_WITH_YOUR_EMAIL@example.com",   // where each response is emailed
  CONTACT: "admin@scholarsequity.org",          // volunteers' replies go here
  FROM_NAME: "Scholars Equity Network",
  SEND_CONFIRMATION_TO_VOLUNTEER: true,
  MAX_PER_HOUR: 60                              // safety limit against spam
};

const STATES = "AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY".split(" ");

function doGet() { return out_({ ok: true, message: "SEN gift form is running." }); }

function doPost(e) {
  try {
    const d = JSON.parse((e && e.postData && e.postData.contents) || "{}");
    if (clean_(d.honey, 50)) return out_({ ok: true });                 // spam trap: pretend success

    const v = validate_(d);
    if (v.error) return out_({ ok: false, error: v.error });

    // Safety limits (no personal data is kept, only counters)
    const cache = CacheService.getScriptCache();
    const hourKey = "n" + Utilities.formatDate(new Date(), "UTC", "yyyyMMddHH");
    const count = Number(cache.get(hourKey) || 0);
    if (count >= CONFIG.MAX_PER_HOUR) return out_({ ok: false, error: "busy" });
    cache.put(hourKey, String(count + 1), 3600);

    // Same person + same gift within 6 hours: don't send a second copy
    const digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, v.email.toLowerCase() + "|" + v.gift);
    const dupKey = "d" + Utilities.base64EncodeWebSafe(digest).slice(0, 40);
    if (cache.get(dupKey)) return out_({ ok: true, duplicate: true });

    const lines = [
      "Gift chosen: " + v.gift,
      v.amazon ? "Amazon link: " + v.amazon : "",
      v.note ? "NOTE: " + v.note : "",
      "",
      "Ship to:",
      v.name,
      v.street + (v.unit ? ", " + v.unit : ""),
      v.city + ", " + v.state + " " + v.zip,
      "",
      "Volunteer email: " + v.email,
      "Received: " + new Date().toString()
    ].filter(function (l, i, a) { return !(l === "" && a[i - 1] === ""); });

    MailApp.sendEmail({
      to: CONFIG.TO, replyTo: v.email, name: CONFIG.FROM_NAME,
      subject: "Gift choice: " + v.gift + " (" + v.name + ")",
      body: lines.join("\n")
    });
    cache.put(dupKey, "1", 21600);

    if (CONFIG.SEND_CONFIRMATION_TO_VOLUNTEER) {
      try {
        MailApp.sendEmail({
          to: v.email, replyTo: CONFIG.CONTACT, name: CONFIG.FROM_NAME,
          subject: "Thank you from Scholars Equity Network",
          body: "Thank you for everything you do!\n\nWe've got your pick: " + v.gift +
                ". We'll get it ready and send it your way.\n\nQuestions? Email " + CONFIG.CONTACT +
                ".\n\n- Scholars Equity Network"
        });
      } catch (ignore) { /* the main email already went out */ }
    }
    return out_({ ok: true });
  } catch (err) {
    return out_({ ok: false, error: "server" });
  }
}

function validate_(d) {
  const v = {
    gift: clean_(d.gift, 80), amazon: clean_(d.amazon, 200), note: clean_(d.note, 200),
    name: clean_(d.name, 100), email: clean_(d.email, 200),
    street: clean_(d.street, 120), unit: clean_(d.unit, 40), city: clean_(d.city, 80),
    state: clean_(d.state, 2).toUpperCase(), zip: clean_(d.zip, 10)
  };
  if (!v.gift) return { error: "gift" };
  if (v.amazon && v.amazon.indexOf("https://www.amazon.com/") !== 0) v.amazon = "";
  if (v.name.length < 2) return { error: "name" };
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v.email)) return { error: "email" };
  if (v.street.length < 3) return { error: "street" };
  if (v.city.length < 2) return { error: "city" };
  if (STATES.indexOf(v.state) < 0) return { error: "state" };
  if (!/^\d{5}(-\d{4})?$/.test(v.zip)) return { error: "zip" };
  if (v.unit === "-") v.unit = "";
  return v;
}

function clean_(s, max) { return String(s == null ? "" : s).replace(/[\r\n\t]+/g, " ").trim().slice(0, max); }
function out_(obj) { return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON); }
