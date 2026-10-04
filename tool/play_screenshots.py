#!/usr/bin/env python3
"""Replace the store listing screenshots of a Google Play listing.

The listing counterpart of play_upload.py: one Play Developer API "edit" —
open, drop the images of one type for one language, upload the new ones in
file name order, commit. Shared by every tracker app.

    play_screenshots.py <package name> <image dir> [--language en-US]
                        [--type phoneScreenshots] [--key sa.json] [--dry-run]

The image directory's *.png / *.jpg are uploaded sorted by name, and that is
the order the listing shows them in — so name them 01_…, 02_…. Play takes at
most 8 per type. Only the given image type of the given language is touched:
the feature graphic, the icon and every other language stay as they are.

Credentials are a service account JSON key (PLAY_SERVICE_ACCOUNT_JSON or --key)
that Play Console → Users and permissions granted "Manage store presence" for
the app; "Release to testing tracks" alone is not enough to edit a listing.

Needs: pip3 install google-api-python-client google-auth
"""

import argparse
import json
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
MAX_IMAGES = 8
EXTENSIONS = (".png", ".jpg", ".jpeg")
MIME = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}


def fail(message):
    print(f"play_screenshots: {message}", file=sys.stderr)
    sys.exit(1)


def api_message(error):
    """The human-readable part of a Play API error, if the body carries one."""
    try:
        return json.loads(error.content)["error"]["message"]
    except (ValueError, KeyError, TypeError):
        return str(error)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("package", help="applicationId, e.g. rs.antonijevic.bird_tracker")
    parser.add_argument("images", help="directory of the screenshots, uploaded in file name order")
    parser.add_argument("--language", default="en-US", help="listing language (default: en-US)")
    parser.add_argument("--type", default="phoneScreenshots", dest="image_type",
                        help="phoneScreenshots | sevenInchScreenshots | tenInchScreenshots | "
                             "featureGraphic | icon (default: phoneScreenshots)")
    parser.add_argument("--key", default=os.environ.get("PLAY_SERVICE_ACCOUNT_JSON"),
                        help="service account JSON key (default: $PLAY_SERVICE_ACCOUNT_JSON)")
    parser.add_argument("--dry-run", action="store_true", help="read only, print the plan")
    args = parser.parse_args()

    if not args.key:
        fail("no service account key: set PLAY_SERVICE_ACCOUNT_JSON or pass --key")
    if not os.path.isfile(args.key):
        fail(f"service account key not found: {args.key}")
    if not os.path.isdir(args.images):
        fail(f"image directory not found: {args.images}")

    files = sorted(os.path.join(args.images, name) for name in os.listdir(args.images)
                   if name.lower().endswith(EXTENSIONS))
    if not files:
        fail(f"no {' / '.join(EXTENSIONS)} in {args.images}")
    if len(files) > MAX_IMAGES:
        fail(f"{len(files)} images in {args.images} — Play takes at most {MAX_IMAGES} per type")

    credentials = service_account.Credentials.from_service_account_file(args.key, scopes=SCOPES)
    edits = build("androidpublisher", "v3", credentials=credentials, cache_discovery=False).edits()
    package, language, image_type = args.package, args.language, args.image_type
    dry = "(dry run) " if args.dry_run else ""

    try:
        edit_id = edits.insert(packageName=package, body={}).execute()["id"]

        languages = [listing["language"] for listing
                     in edits.listings().list(packageName=package, editId=edit_id).execute()
                     .get("listings", [])]
        if language not in languages:
            fail(f"{package} has no '{language}' listing (it has: {', '.join(languages) or 'none'}) — "
                 "a new language needs its title and descriptions, added in the Play Console")

        current = edits.images().list(packageName=package, editId=edit_id,
                                      language=language, imageType=image_type).execute().get("images", [])
        print(f"==> {package} / {language} / {image_type}")
        print(f"    {dry}replace {len(current)} image(s) with {len(files)}:")
        for path in files:
            print(f"      {os.path.basename(path)} ({os.path.getsize(path) / 1e3:.0f} kB)")

        if args.dry_run:
            edits.delete(packageName=package, editId=edit_id).execute()
            print("✓ dry run: nothing was changed")
            return

        if current:
            edits.images().deleteall(packageName=package, editId=edit_id,
                                     language=language, imageType=image_type).execute()
        for path in files:
            media = MediaFileUpload(path, mimetype=MIME[os.path.splitext(path)[1].lower()])
            edits.images().upload(packageName=package, editId=edit_id, language=language,
                                  imageType=image_type, media_body=media).execute()
            print(f"    uploaded {os.path.basename(path)}")

        # Same as play_upload: a pending, unrelated console change makes Play
        # refuse to auto-submit the edit for review. A listing change does need
        # the review to go live, so say so instead of swallowing it.
        try:
            edits.commit(packageName=package, editId=edit_id).execute()
            print("    committed and sent for review")
        except HttpError as error:
            if "changesNotSentForReview" not in api_message(error):
                raise
            edits.commit(packageName=package, editId=edit_id, changesNotSentForReview=True).execute()
            print("    committed WITHOUT review (Play refused to auto-submit: another change is "
                  "pending in the console) — send the changes for review there")
    except HttpError as error:
        fail(f"Play API {error.resp.status}: {api_message(error)}")

    print(f"✓ {len(files)} {image_type} on the {language} listing of {package}")


if __name__ == "__main__":
    main()
