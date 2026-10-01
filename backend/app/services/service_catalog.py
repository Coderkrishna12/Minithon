"""Known online services: name, category, domain and Android package prefixes.

Used to turn raw import signals (an installed app, a URL in a password export,
a domain in an email) into a properly categorised account.
"""
from __future__ import annotations

# (name, category, domain, android package prefixes, typical login)
SERVICES: list[tuple[str, str, str, tuple[str, ...], str]] = [
    # Email and identity providers
    ("Gmail", "email", "gmail.com", ("com.google.android.gm",), "password"),
    ("Google", "email", "google.com", ("com.google.android.googlequicksearchbox",), "password"),
    ("Outlook", "email", "outlook.com", ("com.microsoft.office.outlook",), "password"),
    ("Yahoo Mail", "email", "yahoo.com", ("com.yahoo.mobile.client.android.mail",), "password"),
    ("Proton Mail", "email", "proton.me", ("ch.protonmail.android",), "password"),
    ("iCloud", "cloud", "icloud.com", (), "password"),
    # Social and messaging
    ("Instagram", "social", "instagram.com", ("com.instagram.android",), "password"),
    ("Facebook", "social", "facebook.com", ("com.facebook.katana", "com.facebook.lite"), "password"),
    ("Messenger", "social", "messenger.com", ("com.facebook.orca",), "facebook_sso"),
    ("WhatsApp", "social", "whatsapp.com", ("com.whatsapp",), "phone"),
    ("Telegram", "social", "telegram.org", ("org.telegram.messenger",), "phone"),
    ("Snapchat", "social", "snapchat.com", ("com.snapchat.android",), "password"),
    ("X (Twitter)", "social", "x.com", ("com.twitter.android",), "password"),
    ("LinkedIn", "work", "linkedin.com", ("com.linkedin.android",), "password"),
    ("Reddit", "social", "reddit.com", ("com.reddit.frontpage",), "password"),
    ("Discord", "social", "discord.com", ("com.discord",), "password"),
    ("Threads", "social", "threads.net", ("com.instagram.barcelona",), "password"),
    ("Pinterest", "social", "pinterest.com", ("com.pinterest",), "password"),
    ("ShareChat", "social", "sharechat.com", ("in.mohalla.sharechat",), "phone"),
    ("Truecaller", "social", "truecaller.com", ("com.truecaller",), "phone"),
    # Finance and payments
    ("PayPal", "finance", "paypal.com", ("com.paypal.android",), "password"),
    ("Google Pay", "finance", "pay.google.com", ("com.google.android.apps.nbu.paisa.user",), "google_sso"),
    ("PhonePe", "finance", "phonepe.com", ("com.phonepe.app",), "phone"),
    ("Paytm", "finance", "paytm.com", ("net.one97.paytm",), "phone"),
    ("CRED", "finance", "cred.club", ("com.dreamplug.androidapp",), "phone"),
    ("BHIM", "finance", "bhimupi.org.in", ("in.org.npci.upiapp",), "phone"),
    ("HDFC Bank", "finance", "hdfcbank.com", ("com.snapwork.hdfc", "com.hdfcbank"), "password"),
    ("ICICI Bank", "finance", "icicibank.com", ("com.csam.icici", "com.icicibank"), "password"),
    ("SBI YONO", "finance", "onlinesbi.sbi", ("com.sbi.lotusintouch", "com.sbi.SBIFreedomPlus"), "password"),
    ("Axis Bank", "finance", "axisbank.com", ("com.axis.mobile",), "password"),
    ("Kotak Bank", "finance", "kotak.com", ("com.msf.kbank",), "password"),
    ("Zerodha Kite", "finance", "zerodha.com", ("com.zerodha.kite3",), "password"),
    ("Groww", "finance", "groww.in", ("com.nextbillion.groww",), "google_sso"),
    ("Upstox", "finance", "upstox.com", ("in.upstox",), "password"),
    ("Coinbase", "finance", "coinbase.com", ("com.coinbase.android",), "password"),
    ("Binance", "finance", "binance.com", ("com.binance.dev",), "password"),
    ("Revolut", "finance", "revolut.com", ("com.revolut.revolut",), "phone"),
    ("Venmo", "finance", "venmo.com", ("com.venmo",), "password"),
    ("Cash App", "finance", "cash.app", ("com.squareup.cash",), "phone"),
    # Shopping and delivery
    ("Amazon", "shopping", "amazon.com", ("com.amazon.mShop", "in.amazon.mShop"), "password"),
    ("Flipkart", "shopping", "flipkart.com", ("com.flipkart.android",), "phone"),
    ("Myntra", "shopping", "myntra.com", ("com.myntra.android",), "phone"),
    ("Meesho", "shopping", "meesho.com", ("com.meesho.supply",), "phone"),
    ("Ajio", "shopping", "ajio.com", ("com.ril.ajio",), "phone"),
    ("Nykaa", "shopping", "nykaa.com", ("com.fsn.nykaa",), "phone"),
    ("Swiggy", "shopping", "swiggy.com", ("in.swiggy.android",), "phone"),
    ("Zomato", "shopping", "zomato.com", ("com.application.zomato",), "phone"),
    ("Blinkit", "shopping", "blinkit.com", ("com.grofers.customerapp",), "phone"),
    ("Zepto", "shopping", "zeptonow.com", ("com.zeptoconsumerapp",), "phone"),
    ("BigBasket", "shopping", "bigbasket.com", ("com.bigbasket.mobileapp",), "phone"),
    ("eBay", "shopping", "ebay.com", ("com.ebay.mobile",), "password"),
    ("AliExpress", "shopping", "aliexpress.com", ("com.alibaba.aliexpresshd",), "password"),
    ("Uber", "shopping", "uber.com", ("com.ubercab",), "phone"),
    ("Ola", "shopping", "olacabs.com", ("com.olacabs.customer",), "phone"),
    ("Rapido", "shopping", "rapido.bike", ("com.rapido.passenger",), "phone"),
    ("MakeMyTrip", "shopping", "makemytrip.com", ("com.makemytrip",), "phone"),
    ("IRCTC", "shopping", "irctc.co.in", ("cris.org.in.prs.ima",), "password"),
    ("Airbnb", "shopping", "airbnb.com", ("com.airbnb.android",), "password"),
    # Cloud and productivity
    ("Google Drive", "cloud", "drive.google.com", ("com.google.android.apps.docs",), "google_sso"),
    ("Google Photos", "cloud", "photos.google.com", ("com.google.android.apps.photos",), "google_sso"),
    ("Dropbox", "cloud", "dropbox.com", ("com.dropbox.android",), "password"),
    ("OneDrive", "cloud", "onedrive.live.com", ("com.microsoft.skydrive",), "microsoft_sso"),
    ("Mega", "cloud", "mega.nz", ("mega.privacy.android.app",), "password"),
    ("Notion", "productivity", "notion.so", ("notion.id",), "google_sso"),
    ("Canva", "productivity", "canva.com", ("com.canva.editor",), "google_sso"),
    ("Evernote", "productivity", "evernote.com", ("com.evernote",), "password"),
    ("Adobe", "productivity", "adobe.com", ("com.adobe.reader", "com.adobe.lrmobile", "com.adobe.scan.android"), "password"),
    ("Microsoft 365", "productivity", "office.com", ("com.microsoft.office.officehubrow",), "microsoft_sso"),
    ("Zoom", "work", "zoom.us", ("us.zoom.videomeetings",), "password"),
    ("Slack", "work", "slack.com", ("com.Slack",), "password"),
    ("Microsoft Teams", "work", "teams.microsoft.com", ("com.microsoft.teams",), "microsoft_sso"),
    ("GitHub", "work", "github.com", ("com.github.android",), "password"),
    ("GitLab", "work", "gitlab.com", (), "password"),
    ("Figma", "work", "figma.com", (), "google_sso"),
    ("1Password", "productivity", "1password.com", ("com.onepassword.android",), "password"),
    ("Bitwarden", "productivity", "bitwarden.com", ("com.x8bit.bitwarden",), "password"),
    ("LastPass", "productivity", "lastpass.com", ("com.lastpass.lpandroid",), "password"),
    # Entertainment and gaming
    ("Netflix", "entertainment", "netflix.com", ("com.netflix.mediaclient",), "password"),
    ("YouTube", "entertainment", "youtube.com", ("com.google.android.youtube",), "google_sso"),
    ("Spotify", "entertainment", "spotify.com", ("com.spotify.music",), "password"),
    ("Prime Video", "entertainment", "primevideo.com", ("com.amazon.avod.thirdpartyclient",), "password"),
    ("JioCinema", "entertainment", "jiocinema.com", ("com.jio.media.ondemand",), "phone"),
    ("Hotstar", "entertainment", "hotstar.com", ("in.startv.hotstar",), "phone"),
    ("SonyLIV", "entertainment", "sonyliv.com", ("com.sonyliv",), "phone"),
    ("JioSaavn", "entertainment", "jiosaavn.com", ("com.jio.media.jiobeats",), "phone"),
    ("Twitch", "entertainment", "twitch.tv", ("tv.twitch.android.app",), "password"),
    ("Steam", "gaming", "steampowered.com", ("com.valvesoftware.android.steam.community",), "password"),
    ("Epic Games", "gaming", "epicgames.com", ("com.epicgames",), "password"),
    ("BGMI", "gaming", "battlegroundsmobileindia.com", ("com.pubg.imobile",), "phone"),
    ("Free Fire", "gaming", "ff.garena.com", ("com.dts.freefireth",), "google_sso"),
    ("Roblox", "gaming", "roblox.com", ("com.roblox.client",), "password"),
    ("Dream11", "gaming", "dream11.com", ("com.app.dream11",), "phone"),
    ("Duolingo", "productivity", "duolingo.com", ("com.duolingo",), "google_sso"),
]

_BY_DOMAIN = {domain: s for s in SERVICES for domain in [s[2]]}
_BY_NAME = {s[0].lower(): s for s in SERVICES}


def _base_domain(host: str) -> str:
    host = host.lower().strip().removeprefix("https://").removeprefix("http://").split("/")[0].split(":")[0]
    host = host.removeprefix("www.").removeprefix("m.").removeprefix("accounts.").removeprefix("login.")
    return host


def lookup(name: str | None = None, url: str | None = None, package: str | None = None):
    """Return (name, category, domain, login) for a known service, or None."""
    if package:
        best = None
        for s in SERVICES:
            for prefix in s[3]:
                if package == prefix or package.startswith(prefix + "."):
                    if not best or len(prefix) > best[0]:
                        best = (len(prefix), s)
        if best:
            s = best[1]
            return s[0], s[1], s[2], s[4]
    if url:
        host = _base_domain(url)
        while host and "." in host:
            if host in _BY_DOMAIN:
                s = _BY_DOMAIN[host]
                return s[0], s[1], s[2], s[4]
            host = host.split(".", 1)[1]
    if name:
        s = _BY_NAME.get(name.strip().lower())
        if s:
            return s[0], s[1], s[2], s[4]
    return None
