#!/usr/bin/env python3
"""Play Console 스토어 등록정보를 API 로 읽고 쓴다.

## 왜 API 인가

Play Console 의 애셋 업로드는 OS 파일 선택창을 띄운다. 브라우저 자동화로는 그 창에
닿을 수 없고, 콘솔은 Trusted Types 로 페이지 안 JS 실행도 막아 둬서 숨은 파일 입력에
직접 넣는 우회로도 없다(2026-09-01 실제로 막힘). API 는 그 전부를 건너뛴다.

## 자격증명

`PLAY_SERVICE_ACCOUNT_JSON` 하나면 된다. `android-release.yml` 이 내부 테스트 업로드에
쓰는 것과 같은 키다. 새로 만들 것이 없다.

**서비스 계정에 "스토어 등록정보" 편집 권한이 있어야 한다.** 앱 번들 업로드 권한만
있으면 이미지 업로드가 403 으로 끝난다. Play Console → 사용자 및 권한에서 준다.

## 두 단계로 나눈 이유

`commit` 은 되돌릴 수 없다. 그리고 이미지만 올려도 같은 edit 안의 텍스트가 함께
반영되므로, 콘솔에 저장해 둔 문구를 모르고 덮어쓸 위험이 있다. 그래서 먼저
`inspect` 로 현재 값을 그대로 읽어 눈으로 확인하고, `apply` 는 **읽은 텍스트를 손대지
않은 채** 이미지만 바꾼다.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path

import google.auth.transport.requests
from google.oauth2 import service_account

PACKAGE = "com.nugabox.nuplex"
LANGUAGE = "ko-KR"
BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "resources" / "store" / "play"

# imageType → 올릴 파일. phoneScreenshots 는 순서가 스토어 노출 순서가 된다.
IMAGES: dict[str, list[Path]] = {
    "icon": [ASSETS / "icon-512.png"],
    "featureGraphic": [ASSETS / "feature-1024x500.png"],
    "phoneScreenshots": sorted((ASSETS / "screenshots").glob("*.png")),
}


def token() -> str:
    raw = os.environ["PLAY_SERVICE_ACCOUNT_JSON"]
    creds = service_account.Credentials.from_service_account_info(
        json.loads(raw), scopes=[SCOPE]
    )
    creds.refresh(google.auth.transport.requests.Request())
    return creds.token


def call(method: str, url: str, tok: str, body: bytes | None = None,
         content_type: str | None = None) -> dict:
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", f"Bearer {tok}")
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req) as res:
            payload = res.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        raise SystemExit(f"{method} {url}\n  HTTP {e.code}\n  {detail}") from e


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "inspect"
    if mode not in {"inspect", "apply"}:
        raise SystemExit("사용법: play-listing.py [inspect|apply]")

    tok = token()
    edit = call("POST", f"{BASE}/applications/{PACKAGE}/edits", tok)
    edit_id = edit["id"]
    print(f"edit {edit_id} 를 열었다 (mode={mode})\n")

    listing = call(
        "GET", f"{BASE}/applications/{PACKAGE}/edits/{edit_id}/listings/{LANGUAGE}", tok
    )
    print("── 현재 텍스트 ──")
    print(f"앱 이름       : {listing.get('title', '')!r}")
    print(f"간단한 설명   : {listing.get('shortDescription', '')!r}")
    full = listing.get("fullDescription", "")
    print(f"자세한 설명   : {len(full)}자")
    print(full)
    print()

    print("── 현재 이미지 ──")
    for kind in IMAGES:
        got = call(
            "GET",
            f"{BASE}/applications/{PACKAGE}/edits/{edit_id}/images/{LANGUAGE}/{kind}",
            tok,
        )
        print(f"{kind}: {len(got.get('images', []))}장")
    print()

    if mode == "inspect":
        # edit 을 커밋하지 않고 버린다. 아무것도 바뀌지 않는다.
        call("DELETE", f"{BASE}/applications/{PACKAGE}/edits/{edit_id}", tok)
        print("읽기만 하고 edit 을 버렸다. 바뀐 것은 없다.")
        return

    print("── 올릴 것 ──")
    for kind, paths in IMAGES.items():
        for p in paths:
            if not p.exists():
                raise SystemExit(f"파일이 없다: {p}")
            print(f"{kind}: {p.relative_to(ROOT)} ({p.stat().st_size // 1024}KB)")
    print()

    for kind, paths in IMAGES.items():
        # 같은 것을 두 번 올려 쌓이지 않게 먼저 비운다.
        call(
            "DELETE",
            f"{BASE}/applications/{PACKAGE}/edits/{edit_id}/images/{LANGUAGE}/{kind}",
            tok,
        )
        for p in paths:
            call(
                "POST",
                f"{UPLOAD}/applications/{PACKAGE}/edits/{edit_id}"
                f"/images/{LANGUAGE}/{kind}?uploadType=media",
                tok,
                body=p.read_bytes(),
                content_type="image/png",
            )
            print(f"올림: {kind} ← {p.name}")

    call("POST", f"{BASE}/applications/{PACKAGE}/edits/{edit_id}:commit", tok)
    print("\ncommit 했다. 텍스트는 읽은 그대로 두었고 이미지만 바꿨다.")


if __name__ == "__main__":
    main()
