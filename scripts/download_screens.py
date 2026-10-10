import argparse
import concurrent.futures
import json
import mimetypes
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DEFAULT_PROJECT_ID = "9850514973960087780"
DEFAULT_OUTPUT_DIR = ".stitch"
API_ROOT = "https://stitch.googleapis.com/v1"

# Each screen is placed beneath its documented parent where known. The category
# remains the screen's primary domain even when a cross-domain parent owns the
# nested path. Unlisted live screens are classified by their Stitch title.
SCREEN_LAYOUTS = {
    "e94d669cef5a4ad5bcf0a7ed72e7e938": ("Brand-Onboarding", "Home-Empty-State"),
    "e166be75965c43b5b525bbf2a9213a7f": ("Brand-Onboarding", "Pencild-Splash-Screen"),
    "16ba66e852cf4f05bdfd0def84d89899": ("Ingestion-Capture-Flow", "Source-Chooser"),
    "a307a3147a1f47d7ab545178a0eabd81": ("Ingestion-Capture-Flow", "Source-Chooser/Scan-Processing-Progress"),
    "81223b00062b46c0a06a0c79a6b5ad60": ("Ingestion-Capture-Flow", "Source-Chooser/Batch-Scan-Queue"),
    "fa88dc61326541fa9796e1dff8692b94": ("Ingestion-Capture-Flow", "Source-Chooser/Batch-Scan-Queue-V2"),
    "ec7fcceed7a24971ae74c7b9d0dbbca7": ("Extraction-Review-Pipeline", "Source-Chooser/Scan-Processing-Progress/Event-Review-And-Edit"),
    "b96499d3188a4b52a2cd386e3b4e8f28": ("Extraction-Review-Pipeline", "Source-Chooser/Batch-Scan-Queue/Review-Multiple-Events"),
    "b726b180de014de4a88b13d4f315f7e5": ("Extraction-Review-Pipeline", "Automatic-Review"),
    "f0b02ea3d50e452e91c61fe03ba087ba": ("Extraction-Review-Pipeline", "Source-Chooser/Scan-Processing-Progress/Event-Review-And-Edit/Extraction-Details"),
    "9f640bd6ad79459898892de895391544": ("Extraction-Review-Pipeline", "Source-Chooser/PDF-And-File-Review"),
    "dfbea9bc83d1466aba5974c253b4db71": ("Extraction-Review-Pipeline", "Source-Chooser/Screenshot-Triage"),
    "c9534010e1114ba7bd297edc22f1c9ff": ("Calendar-Event-Details", "Agenda"),
    "5b23fc34d25d47949a1229ac42cebfad": ("Calendar-Event-Details", "Agenda/Event-Details"),
    "cf306ab941854322aaf0d07d7c533a91": ("Calendar-Event-Details", "Source-Chooser/Scan-Processing-Progress/Event-Review-And-Edit/Saved-Event-Detail"),
    "71a8a0266972488d886fc1ccb2aea981": ("Calendar-Event-Details", "Agenda/Event-Details/Edit-Event"),
    "117742cd4c37404ca2238afe1be6a047": ("Calendar-Event-Details", "Agenda/Event-Details/Reminder-Schedule-Editor"),
    "d03171235a96456a9249a4daa03c7624": ("Calendar-Event-Details", "History-And-Archive"),
    "0f3874c6088b482b872bfd5b5f312eb7": ("Settings-Functional-Sub-Screens", "Settings"),
    "22898da21df9424ab424cfbfef45fd03": ("Settings-Functional-Sub-Screens", "Settings/Automatic-Capture"),
    "7dd0255a932141d79138f3b97a452fc9": ("Settings-Functional-Sub-Screens", "Settings/Source-Preferences"),
    "f3d0483edc2a43438cfa34e37205fecd": ("Settings-Functional-Sub-Screens", "Settings/Default-Calendar"),
    "4f7fb7c09ca442b1935ed0f729924f6b": ("Settings-Functional-Sub-Screens", "Settings/Notification-Preferences"),
    "e2ef8e9041a74d2fa2dd543b653fa2d3": ("Settings-Functional-Sub-Screens", "Settings/Reminder-Presets"),
    "89f60140b09c4ad78fc9705e9dbbde84": ("Settings-Functional-Sub-Screens", "Settings/Smart-Suggestions"),
    "0af7876285d64dd59f9b6f1a25285fe2": ("Settings-Functional-Sub-Screens", "Settings/Privacy-And-Processing"),
    "5681a6bf69114d778619f925469aa25e": ("Settings-Functional-Sub-Screens", "Settings/App-Preferences"),
    "7098b1759cde482ab97dfcbbdeb9ccfc": ("Settings-Functional-Sub-Screens", "Settings/Help-And-Support"),
    "80ec0320a47a4f6f9ff8c98bec1e6a5d": ("Account-Security-Verification", "Settings/User-Profile"),
    "1e01d494177a4ab4bff2ef6014d788e4": ("Account-Security-Verification", "Settings/User-Profile/Verify-Phone-Number"),
    "b01ff3968f5a41e091549e94981e6563": ("Account-Security-Verification", "Settings/User-Profile/Verify-Phone-Number/Enter-Phone-SMS-Code"),
    "10feefa51f1a40699d59b22ebea70b22": ("Account-Security-Verification", "Settings/User-Profile/Verify-Email-Address"),
    "cf05d2e2cc52430093ad092c8a62d76c": ("Account-Security-Verification", "Settings/User-Profile/Verify-Email-Address/Check-Email-Inbox"),
    "a77a1855fc904c529b04aada1d00c5a7": ("Account-Security-Verification", "Settings/User-Profile/Verification-Complete"),
    "b049d1c4c3e7491f867bc5ebd8224b99": ("Monetization-Subscription-Paywalls", "Premium-Paywall"),
    "7296411f5d9446e3b334a9ab09abf898": ("Monetization-Subscription-Paywalls", "Plus-Paywall"),
    "b9eabf1d24fb4c7f9e392cd9d58159e3": ("Monetization-Subscription-Paywalls", "Premium-Paywall/Manage-Subscription"),
    "9cd18db50bf64b8a80431e483052c853": ("Edge-States", "Source-Chooser/Scan-Processing-Progress/No-Dates-Found"),
    "8e89625cc96f49c48ebed8bfef75b9b0": ("Edge-States", "Settings/Default-Calendar/Calendar-Permission-Denied"),
    "6eb304b327e6400ba203aa40d9798a85": ("Edge-States", "Settings/Notification-Preferences/Notification-Permission-Denied"),
    "c260982726f743cd973a064579946822": ("Marketing-Assets", "App-Store-Slide-iPhone-01"),
    "5d72d1bfbe5445ddbd33416047296fce": ("Marketing-Assets", "App-Store-Slide-iPad-01"),
    "f34bff7100624055a748acfa6120bf00": ("Marketing-Assets", "App-Store-Slide-iPad-02"),
    "3702545456768888067": ("Marketing-Assets", "Pencild-Splash-Background"),
    "a8d2a1e82bfb4dd3834278ae259c8b08": ("Marketing-Assets", "App-Store-Slide-iPhone-02"),
    "a105af88940f4be898ef475ce2735202": ("Marketing-Assets", "App-Store-Slide-iPad-03"),
    "9a80e3a825074d8d969672ee54302157": ("Marketing-Assets", "App-Store-Slide-iPhone-03"),
    "5d702c95d77145e183ca08b60cfcb2cd": ("Marketing-Assets", "App-Store-Slide-iPhone-04"),
    "11975388127119735582": ("Marketing-Assets", "Pencild-Logo-Grey"),
    "2828115625404236044": ("Marketing-Assets", "Marketing-Kit"),
    "65a70a58868f45a6b2af0f64ff6ebc54": ("Marketing-Assets", "Digital-Banner-Ad"),
    "a71e5d0aabda40b2ac31b4b9d953dc1e": ("Marketing-Assets", "Marketing-Copy-Email-Template"),
    "8019306492019719328": ("Marketing-Assets", "Pencil-Tip-App-Icon-Design"),
    "051be17bb3994b2f9b4a5cbf02b6f4f9": ("Marketing-Assets", "App-Store-Slide-iPhone-05"),
    "8019306492019717442": ("Marketing-Assets", "Pencild-Full-Logo-Wordmark"),
    "ec6850f39a674f65951ab4313389a227": ("Marketing-Assets", "Email-Newsletter-Header"),
    "06c2df8676394c1eb9c6377c56a6e302": ("Marketing-Assets", "Screen-Catalog-Map-01"),
    "b1c4833006a843dcbb7020fdfa831ab9": ("Marketing-Assets", "Screen-Catalog-Map-02"),
}

# Variants and new canvases found in live Stitch but absent from the catalogue.
ADDITIONAL_LAYOUTS = {
    "ed901b9c881e4cda8298bdef00afd3c5": ("Ingestion-Capture-Flow", "Source-Chooser/PDF-And-File-Review-V2"),
    "8b944ed6ba32451fb7522174675b48d2": ("Ingestion-Capture-Flow", "Source-Chooser/IPad-Multi-Page-PDF-Studio"),
    "1574c65146e24402b1548c12b207494e": ("Settings-Functional-Sub-Screens", "Settings/IPad-System-Settings-Dashboard"),
    "b54cdd3a7a784f49b0e2ee59d06f806f": ("Ingestion-Capture-Flow", "Source-Chooser/Camera-Scanner-Viewfinder/Manual-Crop"),
    "f55af4ea2d424f81bba041682f60ad6c": ("Extraction-Review-Pipeline", "Source-Chooser/Batch-Scan-Queue/Review-Multiple-Events/Interactive-Conflict-Resolver"),
    "17727eb4637541f59878f689071d821d": ("Ingestion-Capture-Flow", "Source-Chooser/Share-Sheet-Extension"),
    "665a84429ecd43208d83345d18468c0f": ("Extraction-Review-Pipeline", "Source-Chooser/Scan-Processing-Progress/Event-Review-And-Edit/IPad-Verification-Workspace"),
    "5271fea1db87434293eb874f6aa3ab39": ("Marketing-Assets", "App-Store-Slide-iPad-04"),
    "b881af5986a1461f9571e68991ce5018": ("Ingestion-Capture-Flow", "Source-Chooser/Camera-Scanner-Viewfinder/IPad-Manual-Crop-Keystone"),
    "871fa7b0fe8f45058cbad714b41b1815": ("Ingestion-Capture-Flow", "Source-Chooser/IPad-Multi-Page-PDF-Studio-V2"),
    "4d32dca609f941c5b5124323b30dc1e0": ("Ingestion-Capture-Flow", "Source-Chooser/IPad-Split-View-Ingestion"),
    "fe03ab9294354063a9234feaaa9c88e7": ("Marketing-Assets", "App-Store-Slide-iPad-05"),
    "71d5cd8f67314afaa25a0026a0d03f6b": ("Calendar-Event-Details", "Agenda/IPad-Master-Calendar-Studio"),
    "90b6b3d46c4a42d8ad42bd672440e029": ("Extraction-Review-Pipeline", "Source-Chooser/Screenshot-Triage/IPad-Screenshot-Radar"),
    "ae913430d5004e68b7d820946a2423db": ("Marketing-Assets", "Screen-Catalog-Tri-Layer-Reconciliation"),
    "38827083808141aaaa22ad1e2e03ab59": ("Ingestion-Capture-Flow", "Source-Chooser/IPad-Camera-Scanner-Studio"),
    "a8020536a2a044178e5d763048f14d31": ("Extraction-Review-Pipeline", "Source-Chooser/Batch-Scan-Queue/Review-Multiple-Events/IPad-Conflict-Radar"),
    "55139ee162cd483e8982ae7411ec82a2": ("Calendar-Event-Details", "History-And-Archive/IPad-Document-Archive"),
    "7de387b55bc44943b9db4fc1a3a63bb8": ("Marketing-Assets", "Social-Media-Post"),
    "6e4ba39aa3774840b8581a5581419a7f": ("Ingestion-Capture-Flow", "Source-Chooser/Camera-Scanner-Viewfinder"),
    "ad56d8ee0ed64b04ae789dc6e799b4fe": ("Marketing-Assets", "Live-Canvas-Architecture-Map"),
}

def resolve_project_id(cli_project_id=None):
    if cli_project_id:
        return cli_project_id
    return os.environ.get("STITCH_PROJECT_ID") or os.environ.get("PROJECT_ID") or None


def build_headers(token, project_id=None):
    headers = {"Authorization": f"Bearer {token}"}
    if project_id:
        headers["X-Goog-User-Project"] = project_id
    return headers


def parse_args(args=None):
    parser = argparse.ArgumentParser(description="Download all screens and embedded design tokens from a Stitch project.")
    parser.add_argument("--project-id", default=None, help="Stitch project ID (defaults to Pencil'd project).")
    parser.add_argument("--quota-project", default=None, help="Google Cloud quota project for Stitch API calls; defaults to STITCH_QUOTA_PROJECT or gcloud config.")
    parser.add_argument("--output-dir", default=DEFAULT_OUTPUT_DIR, help="Root output directory (default: .stitch).")
    parser.add_argument("--catalogue", default="docs/plans/pencild-stitch-catalogue.md", help="Canonical catalogue for reconciliation.")
    parser.add_argument("--workers", type=int, default=5, help="Concurrent screen downloads (default: 5).")
    parser.add_argument("--timeout", type=int, default=60, help="HTTP timeout in seconds.")
    return parser.parse_args(args)


def get_token():
    result = subprocess.run(["gcloud", "auth", "print-access-token"], capture_output=True, text=True, check=True)
    return result.stdout.strip()


def resolve_quota_project(cli_quota_project=None):
    if cli_quota_project:
        return cli_quota_project
    if os.environ.get("STITCH_QUOTA_PROJECT"):
        return os.environ["STITCH_QUOTA_PROJECT"]
    result = subprocess.run(["gcloud", "config", "get-value", "project"], capture_output=True, text=True, check=True)
    value = result.stdout.strip()
    return value if value and value != "(unset)" else None


def slugify(text):
    cleaned = re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-")
    return cleaned[:96] or "Untitled-Screen"


def request_json(url, headers, timeout):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def list_project_screens(project_id, headers, timeout):
    screens = []
    page_token = None
    while True:
        params = {"pageSize": "100"}
        if page_token:
            params["pageToken"] = page_token
        url = f"{API_ROOT}/projects/{urllib.parse.quote(project_id, safe='')}/screens?{urllib.parse.urlencode(params)}"
        page = request_json(url, headers, timeout)
        screens.extend(page.get("screens", []))
        page_token = page.get("nextPageToken")
        if not page_token:
            return screens


def catalogue_ids(path):
    ids = set()
    try:
        for line in Path(path).read_text(encoding="utf-8").splitlines():
            if line.startswith("|"):
                match = re.search(r"`([0-9a-f]{8,32})`", line)
                if match:
                    ids.add(match.group(1))
    except FileNotFoundError:
        pass
    return ids


def layout_for(screen):
    screen_id = screen.get("id") or screen.get("name", "").rsplit("/", 1)[-1]
    if screen_id in SCREEN_LAYOUTS:
        return SCREEN_LAYOUTS[screen_id], "catalogue"
    if screen_id in ADDITIONAL_LAYOUTS:
        return ADDITIONAL_LAYOUTS[screen_id], "stitch-only"

    title = screen.get("title", "Untitled Screen")
    slug = slugify(title)
    lower = title.lower()
    if any(word in lower for word in ("app store", "banner", "marketing", "newsletter", "logo", "icon design", "social media", "screen catalog", "architecture map", "reconciliation")):
        category = "Marketing-Assets"
    elif "permission denied" in lower or "no dates found" in lower:
        category = "Edge-States"
    elif "setting" in lower or "calendar" in lower or "agenda" in lower or "archive" in lower or "reminder" in lower:
        category = "Calendar-Event-Details" if any(word in lower for word in ("agenda", "calendar", "archive", "event detail")) else "Settings-Functional-Sub-Screens"
    elif any(word in lower for word in ("review", "event", "conflict", "ocr", "verification")):
        category = "Extraction-Review-Pipeline"
    else:
        category = "Ingestion-Capture-Flow"
    parent = "Agenda" if category == "Calendar-Event-Details" else "Settings" if category == "Settings-Functional-Sub-Screens" else "Source-Chooser" if category == "Ingestion-Capture-Flow" else slug
    relative = f"{parent}/{slug}" if parent != slug else slug
    return (category, relative), "stitch-only"


def download_bytes(url, timeout):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = response.read()
        content_type = response.headers.get("Content-Type", "").split(";", 1)[0].strip().lower()
        return payload, content_type


def validated_html_payload(url, timeout):
    payload, content_type = download_bytes(url, timeout)
    if payload.lstrip().lower().startswith((b"<!doctype html", b"<html")) and b"accounts.google.com/v3/signin" in payload[:10000].lower():
        # Stitch's lh3.googleusercontent screenshot links redirect to an HTML
        # sign-in page. Their corresponding HTML file resource is the full
        # image-generation description for marketing-only records, not an image.
        # Treat this response as unavailable rather than saving it as artwork.
        raise ValueError("Stitch resource redirected to Google sign-in HTML instead of the requested asset")
    if content_type in ("text/html", "application/xhtml+xml") and not payload.lstrip().lower().startswith((b"<!doctype html", b"<html")):
        content_type = "text/plain"
    return payload, content_type


def is_google_signin_page(payload):
    return b"accounts.google.com/v3/signin" in payload[:10000].lower()


def html_is_renderable(payload):
    sample = payload[:1000].lstrip().lower()
    return sample.startswith((b"<!doctype html", b"<html")) or b"<html" in sample


def markdown_is_source_description(payload):
    sample = payload[:1000].lstrip()
    return sample.startswith((b"# ", b"## ", b"- ", b"* ")) or b"### " in sample


def fetch_by_resource_name(resource_name, headers, timeout):
    if not resource_name:
        raise ValueError("No resource name available")
    url = f"https://stitch.googleapis.com/v1/{resource_name.lstrip('/')}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.read(), response.headers.get("Content-Type", "").split(";", 1)[0].strip().lower()


def fetch_optional_design_resource(resource_name, headers, timeout):
    try:
        payload, content_type = fetch_by_resource_name(resource_name, headers, timeout)
        if not payload or payload.lstrip().lower().startswith(b"<!doctype html") and b"accounts.google.com/v3/signin" in payload[:10000].lower():
            return None, "not-available"
        return (payload, content_type), "fetched"
    except urllib.error.HTTPError as error:
        if error.code in (401, 403, 404, 410):
            return None, f"not-available-http-{error.code}"
        raise


def download_optional_html(html_info, headers, timeout):
    html_url = html_info.get("downloadUrl") if isinstance(html_info, dict) else None
    html_name = html_info.get("name") if isinstance(html_info, dict) else None
    if html_url:
        try:
            payload, content_type = validated_html_payload(html_url, timeout)
            if html_is_renderable(payload):
                return (payload, "text/html"), "fetched"
            if content_type.startswith("text/") and markdown_is_source_description(payload):
                return (payload, "text/markdown"), "fetched-description"
        except (urllib.error.URLError, ValueError):
            pass
    if html_name:
        try:
            resource = fetch_by_resource_name(html_name, headers, timeout)
            payload, content_type = resource
            if is_google_signin_page(payload):
                return None, "not-available"
            if html_is_renderable(payload):
                return (payload, "text/html"), "fetched"
            if content_type.startswith("text/") and markdown_is_source_description(payload):
                return (payload, "text/markdown"), "fetched-description"
        except (urllib.error.URLError, urllib.error.HTTPError):
            pass
    return None, "not-available"


def download_optional_screenshot(screenshot_info, headers, timeout):
    screenshot_url = screenshot_info.get("downloadUrl") if isinstance(screenshot_info, dict) else None
    screenshot_name = screenshot_info.get("name") if isinstance(screenshot_info, dict) else None
    if screenshot_url:
        try:
            payload, content_type = download_bytes(screenshot_url, timeout)
            if payload.startswith((b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff")) or payload[:4] == b"RIFF" and payload[8:12] == b"WEBP":
                return (payload, content_type), "fetched"
        except (urllib.error.URLError, ValueError):
            pass
    if screenshot_name:
        try:
            payload, content_type = fetch_by_resource_name(screenshot_name, headers, timeout)
            if payload.startswith((b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff")) or payload[:4] == b"RIFF" and payload[8:12] == b"WEBP":
                return (payload, content_type), "fetched"
        except (urllib.error.URLError, urllib.error.HTTPError):
            pass
    return None, "not-available"


def extension_for(payload, content_type, default):
    if payload.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    if payload.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if payload[:4] == b"RIFF" and payload[8:12] == b"WEBP":
        return ".webp"
    guessed = mimetypes.guess_extension(content_type) if content_type else None
    return guessed or default


def safe_metadata(data):
    # Keep descriptive metadata and resource names, but do not persist expiring signed URLs.
    def scrub(value):
        if isinstance(value, dict):
            return {key: scrub(item) for key, item in value.items() if key != "downloadUrl"}
        if isinstance(value, list):
            return [scrub(item) for item in value]
        return value
    return scrub(data)


def parent_root_category(category, relative_dir):
    # Keep the primary category as the top-level directory even when a screen's
    # parent belongs to another domain; nested parent folders follow beneath it.
    return category


def display_path(path):
    return Path(os.path.relpath(path, Path.cwd())).as_posix()


def download_one(screen_stub, project_id, headers, output_dir, timeout):
    screen_id = screen_stub.get("id") or screen_stub.get("name", "").rsplit("/", 1)[-1]
    category, relative_dir = layout_for(screen_stub)[0]
    root_category = parent_root_category(category, relative_dir)
    target_dir = Path(output_dir) / root_category / relative_dir
    target_dir.mkdir(parents=True, exist_ok=True)
    result = {
        "id": screen_id,
        "title": screen_stub.get("title", screen_id),
        "category": category,
        "directory": display_path(target_dir),
        "catalogueStatus": layout_for(screen_stub)[1],
        "metadataStatus": "failed",
        "htmlStatus": "not-available",
        "screenshotStatus": "not-available",
    }
    try:
        url = f"{API_ROOT}/projects/{urllib.parse.quote(project_id, safe='')}/screens/{urllib.parse.quote(screen_id, safe='')}"
        data = request_json(url, headers, timeout)
        result.update({"title": data.get("title", result["title"]), "deviceType": data.get("deviceType"), "width": data.get("width"), "height": data.get("height"), "screenType": data.get("screenType"), "screenMetadata": data.get("screenMetadata")})
        (target_dir / "screen.json").write_text(json.dumps(safe_metadata(data), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result["metadataStatus"] = "fetched"

        html_info = data.get("htmlCode") or {}
        html_result, html_status = download_optional_html(html_info, headers, timeout)
        if html_result:
            payload, content_type = html_result
            suffix = ".html" if content_type == "text/html" else ".md"
            html_path = target_dir / f"design{suffix}"
            html_path.write_bytes(payload)
            result.update({"htmlStatus": html_status, "htmlFile": display_path(html_path)})
        elif isinstance(html_info, str) and html_info:
            html_path = target_dir / "design.html"
            html_path.write_text(html_info, encoding="utf-8")
            result.update({"htmlStatus": "fetched-inline", "htmlFile": display_path(html_path)})

        screenshot_info = data.get("screenshot") or {}
        screenshot_result, screenshot_status = download_optional_screenshot(screenshot_info, headers, timeout)
        if screenshot_result:
            payload, content_type = screenshot_result
            suffix = extension_for(payload, content_type, ".bin")
            image_path = target_dir / f"screenshot{suffix}"
            image_path.write_bytes(payload)
            result.update({"screenshotStatus": screenshot_status, "screenshotFile": display_path(image_path), "screenshotMimeType": content_type})
        else:
            result["screenshotStatus"] = screenshot_status
        result["designSystem"] = data.get("designSystem")
        result["theme"] = data.get("theme")
    except Exception as error:
        result["error"] = f"{type(error).__name__}: {error}"
    remove_stale_signin_responses(target_dir)
    return result


def remove_stale_signin_responses(target_dir):
    for filename in ("design.html", "screenshot.html"):
        path = target_dir / filename
        if not path.is_file():
            continue
        try:
            prefix = path.read_bytes()[:10000].lower()
        except OSError:
            continue
        if is_google_signin_page(prefix):
            path.unlink()


def extract_icon_references(html_path):
    try:
        html = Path(html_path).read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    candidates = re.findall(r"material-symbols(?:-outlined|-rounded|-sharp)?[^>]*>\s*([^<]+)\s*<", html, re.I)
    names = set()
    for candidate in candidates:
        name = re.sub(r"[^a-z0-9_]+", "", candidate.strip().lower())
        if name:
            names.add(name)
    return sorted(names)


def write_tokens(results, output_dir):
    token_dir = Path(output_dir) / "tokens"
    token_dir.mkdir(parents=True, exist_ok=True)
    design_systems = {}
    themes = []
    icons = {}
    for result in results:
        screen_id = result["id"]
        system = result.get("designSystem")
        if isinstance(system, dict):
            key = system.get("name") or system.get("designSystem", {}).get("displayName") or screen_id
            design_systems[key] = safe_metadata(system)
        theme = result.get("theme")
        if isinstance(theme, dict):
            themes.append({"screenId": screen_id, "title": result["title"], "theme": theme})
        html_file = result.get("htmlFile")
        if html_file and result.get("htmlStatus") == "fetched":
            refs = extract_icon_references(html_file)
            if refs:
                icons[screen_id] = {"title": result["title"], "materialSymbols": refs}
    (token_dir / "design-systems.json").write_text(json.dumps(design_systems, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (token_dir / "screen-themes.json").write_text(json.dumps(themes, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (token_dir / "icon-inventory.json").write_text(json.dumps(icons, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"designSystems": len(design_systems), "screenThemes": len(themes), "screensWithExtractedMaterialSymbols": len(icons)}


def write_manifest(results, live_screens, catalogue_file, token_status, output_dir):
    known_ids = catalogue_ids(catalogue_file)
    live_ids = {row["id"] for row in results}
    absent_from_stitch = sorted(known_ids - live_ids)
    absent_from_catalogue = sorted(live_ids - known_ids)
    lines = [
        "# Stitch Download Manifest", "",        f"**Project:** `{resolve_project_id() or DEFAULT_PROJECT_ID}`", f"**Live screens listed:** {len(live_screens)}", f"**Catalogue IDs:** {len(known_ids)}", f"**Catalogue IDs confirmed present:** {len(known_ids & live_ids)}", f"**Catalogue IDs absent from Stitch:** {len(absent_from_stitch)}", f"**Live IDs absent from catalogue:** {len(absent_from_catalogue)}", "",
        "All project screen metadata, HTML/code and screenshot resources were requested. Status is recorded per artifact below. `fetched` means a file was written and validated; `fetched-description` means Stitch returned Markdown source copy rather than renderable HTML; `not-available` means this screen kind has no usable downloadable artifact endpoint/resource. Google sign-in HTML responses are rejected and are not saved as design assets.", "",
        "## Shared design tokens", "",
        f"- `.stitch/tokens/design-systems.json`: {token_status['designSystems']} unique embedded design systems (style guidelines, semantic colors, geometry/elevation guidance).",
        f"- `.stitch/tokens/screen-themes.json`: {token_status['screenThemes']} per-screen theme records (colors, typography, spacing scale and font metadata).",
        f"- `.stitch/tokens/icon-inventory.json`: symbol references extracted from {token_status['screensWithExtractedMaterialSymbols']} HTML screens. Other inline SVG/image icons remain in each screen's HTML.",
        "- Stitch returns design systems and themes embedded in screen metadata; no separate design-token endpoint/artifact was exposed by this project's response schema.",
        "- Screens can be documentation/asset records rather than visual UI: these may have Markdown descriptions, image-only screenshots, or no renderable screenshot. Status distinguishes these from missing screen metadata.", "",
        "## Screen inventory", "", "| Project ID | Screen title | Category | Target directory | Metadata | HTML/code | Screenshot | Catalogue status |", "|---|---|---|---|---|---|---|---|",
    ]
    for row in sorted(results, key=lambda value: (value["category"], value["directory"], value["id"])):
        title = row["title"].replace("|", "\\|")
        lines.append(f"| `{row['id']}` | {title} | {row['category']} | `{row['directory']}` | {row['metadataStatus']} | {row['htmlStatus']} | {row['screenshotStatus']} | {row['catalogueStatus']} |")
    absent_stitch_lines = [f"- `{item}`" for item in absent_from_stitch] or ["- None."]
    absent_catalogue_lines = [
        f"- `{item['id']}` — {item['title']} (`{item['category']}`, `{item['directory']}`)"
        for item in sorted(results, key=lambda value: value["id"])
        if item["id"] in absent_from_catalogue
    ] or ["- None."]
    lines.extend(["", "## Catalogue IDs not found in Stitch", "", *absent_stitch_lines, "", "## Stitch IDs not in the canonical catalogue", "", *absent_catalogue_lines, ""])
    Path(output_dir, "manifest.md").write_text("\n".join(lines), encoding="utf-8")
    Path(output_dir, "manifest.json").write_text(json.dumps({"projectId": resolve_project_id() or DEFAULT_PROJECT_ID, "listedCount": len(live_screens), "screens": results, "catalogueIdsAbsentFromStitch": absent_from_stitch, "liveIdsAbsentFromCatalogue": absent_from_catalogue, "tokenStatus": token_status}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(args=None):
    parsed = parse_args(args)
    project_id = resolve_project_id(parsed.project_id) or DEFAULT_PROJECT_ID
    quota_project = resolve_quota_project(parsed.quota_project)
    token = get_token()
    headers = build_headers(token, quota_project)
    output_dir = os.path.abspath(parsed.output_dir)
    os.makedirs(output_dir, exist_ok=True)

    screens = list_project_screens(project_id, headers, parsed.timeout)
    if not screens:
        raise RuntimeError(f"Stitch returned no screens for project {project_id}")
    print(f"Listed {len(screens)} screens from Stitch project {project_id}.")
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, parsed.workers)) as executor:
        futures = [executor.submit(download_one, screen, project_id, headers, output_dir, parsed.timeout) for screen in screens]
        for future in concurrent.futures.as_completed(futures):
            row = future.result()
            results.append(row)
            print(f"{row['metadataStatus']}/{row['htmlStatus']}/{row['screenshotStatus']} {row['id']} {row['title']}")
    token_status = write_tokens(results, output_dir)
    write_manifest(results, screens, parsed.catalogue, token_status, output_dir)
    failed = [row for row in results if row["metadataStatus"] != "fetched" or row["htmlStatus"] not in ("fetched", "fetched-description", "fetched-inline", "not-available") or row["screenshotStatus"] not in ("fetched", "not-available")]
    print(f"Wrote {len(results)} screen records, token files, and manifest under {output_dir}.")
    if failed:
        print(f"{len(failed)} screen(s) have one or more incomplete artifacts; see manifest.md.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
