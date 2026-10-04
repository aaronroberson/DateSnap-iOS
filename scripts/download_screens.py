import os
import sys
import subprocess
import json
import urllib.request
import argparse

SCREENS = [
    {"id": "6c145dff8ec540b9a51f806629e55c70", "slug": "01_premium_paywall", "title": "DateSnap - Premium Paywall"},
    {"id": "df7a78364bd54941ad1d7bb6ca34d449", "slug": "02_plus_paywall", "title": "DateSnap - Plus Paywall"},
    {"id": "e5fc50914c2f4a788389e8aa94806f45", "slug": "03_history_and_archive", "title": "DateSnap - History & Archive"},
    {"id": "7d2a6476acc841b7be7374273debbf8b", "slug": "04_calendar_permission_denied", "title": "DateSnap - Calendar Permission Denied"},
    {"id": "1a0a6dacd22344d797031c2746da9b37", "slug": "05_notification_permission_denied", "title": "DateSnap - Notification Permission Denied"},
    {"id": "d973f4ad48f2487ea6be61abce9b19ae", "slug": "06_no_dates_found", "title": "DateSnap - No Dates Found"},
    {"id": "b04278172768466ead0f77aec1e7fefe", "slug": "07_home_empty_state", "title": "DateSnap - Home Empty State"},
    {"id": "79edd80432f24128889607dee9d678f4", "slug": "08_saved_event_detail", "title": "DateSnap - Saved Event Detail"},
    {"id": "50e76e9e2a6743a98d1f320729a3738a", "slug": "09_event_review_and_edit", "title": "DateSnap - Event Review and Edit"},
    {"id": "fc49f1067442461dbf28c683626a3b70", "slug": "10_reminder_schedule_editor", "title": "DateSnap - Reminder Schedule Editor"},
]

def resolve_project_id(cli_project_id=None):
    if cli_project_id:
        return cli_project_id
    return os.environ.get("STITCH_PROJECT_ID") or os.environ.get("PROJECT_ID") or None

def build_headers(token, project_id=None):
    headers = {
        "Authorization": f"Bearer {token}"
    }
    if project_id:
        headers["X-Goog-User-Project"] = project_id
    return headers

def parse_args(args=None):
    parser = argparse.ArgumentParser(description="Download screen metadata, HTML, and images from Stitch.")
    parser.add_argument(
        "--project-id",
        type=str,
        default=None,
        help="Stitch Project ID. Overrides STITCH_PROJECT_ID and PROJECT_ID environment variables."
    )
    return parser.parse_args(args)

def get_token():
    res = subprocess.run(["gcloud", "auth", "print-access-token"], capture_output=True, text=True, check=True)
    return res.stdout.strip()

def main(args=None):
    parsed_args = parse_args(args)
    project_id = resolve_project_id(parsed_args.project_id)

    if not project_id:
        print("Warning: No project ID provided. Please set STITCH_PROJECT_ID or PROJECT_ID environment variable, or pass --project-id.", file=sys.stderr)

    token = get_token()
    out_dir = os.path.abspath(".stitch/screens")
    os.makedirs(out_dir, exist_ok=True)
    
    metadata_list = []
    
    for item in SCREENS:
        screen_id = item["id"]
        slug = item["slug"]
        title = item["title"]
        print(f"Fetching screen metadata: {title} ({screen_id})...")
        
        url = f"https://stitch.googleapis.com/v1/projects/{project_id or ''}/screens/{screen_id}"
        req = urllib.request.Request(
            url,
            headers=build_headers(token, project_id)
        )
        try:
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode())
        except Exception as e:
            print(f"Error fetching {screen_id}: {e}", file=sys.stderr)
            continue
            
        json_path = os.path.join(out_dir, f"{slug}.json")
        with open(json_path, "w") as f:
            json.dump(data, f, indent=2)
            
        html_info = data.get("htmlCode", {})
        screenshot_info = data.get("screenshot", {})
        
        html_url = html_info.get("downloadUrl")
        img_url = screenshot_info.get("downloadUrl")
        
        html_path = os.path.join(out_dir, f"{slug}.html")
        png_path = os.path.join(out_dir, f"{slug}.png")
        
        if html_url:
            print(f"  Downloading HTML via curl -L to {html_path}...")
            subprocess.run(["curl", "-sL", html_url, "-o", html_path], check=True)
        else:
            print(f"  Warning: No htmlCode downloadUrl for {slug}")
            
        if img_url:
            print(f"  Downloading Screenshot via curl -L to {png_path}...")
            subprocess.run(["curl", "-sL", img_url, "-o", png_path], check=True)
        else:
            print(f"  Warning: No screenshot downloadUrl for {slug}")
            
        metadata_list.append({
            "id": screen_id,
            "slug": slug,
            "title": data.get("title", title),
            "htmlFile": f"{slug}.html",
            "imageFile": f"{slug}.png",
            "deviceType": data.get("deviceType"),
            "width": data.get("width"),
            "height": data.get("height"),
        })

    index_path = os.path.join(out_dir, "index.json")
    with open(index_path, "w") as f:
        json.dump(metadata_list, f, indent=2)
    print(f"\nSuccessfully downloaded all {len(metadata_list)} screens to {out_dir}!")

if __name__ == "__main__":
    main()
