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

`commit` 은 되돌릴 수 없다. 그래서 먼저 `inspect` 로 지금 게시된 값을 그대로 읽어
무엇이 바뀌는지 보고, 그다음 `apply` 로 넘어간다.

**새 edit 은 콘솔의 임시보관함이 아니라 "게시된" 값에서 시작한다.** 처음 돌렸을 때
콘솔에는 709자짜리 설명이 보이는데 API 로는 빈 문자열이었다. 이 상태에서 이미지만
올리고 커밋했다면 빈 설명이 그대로 게시될 뻔했다. 그래서 텍스트도 저장소에 두고
`apply` 가 매번 함께 넣는다.
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

# **업로드 호스트가 둘이다.** `androidpublisher.googleapis.com/upload/...` 는
# `Could not find handler for this request` 로 404 가 난다(2026-09-01 확인).
# 미디어 업로드는 `www.googleapis.com` 쪽에 붙어 있다. 어느 쪽이 통했는지 로그에
# 남기려고 목록으로 둔다 — 나중에 반대로 바뀌어도 바로 보인다.
UPLOAD_HOSTS = [
    "https://www.googleapis.com/upload/androidpublisher/v3",
    "https://androidpublisher.googleapis.com/upload/androidpublisher/v3",
]
SCOPE = "https://www.googleapis.com/auth/androidpublisher"

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "resources" / "store" / "play"

# 텍스트도 저장소에 둔다. 콘솔에만 있으면 무엇이 올라가 있는지 코드로 알 수 없고,
# API 로 이미지를 커밋할 때 실수로 비워 버릴 수 있다(2026-09-01 실제로 겪을 뻔했다 —
# 새 edit 은 **게시된** 값에서 시작하는데 그때 설명이 비어 있었다).
TITLE = "NUPLEX"
SHORT_DESCRIPTION = "초대받은 사람들이 함께 쓰는 Plex 서버의 영화·드라마를 둘러보고 바로 재생합니다."
FULL_DESCRIPTION_FILE = ASSETS / "listing-ko.txt"

# Play 가 받는 상한. 넘으면 API 가 거절하기 전에 여기서 잡는다.
LIMITS = {"title": 30, "shortDescription": 80, "fullDescription": 4000}

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
         content_type: str | None = None, tolerate_404: bool = False) -> dict:
    """`tolerate_404` — 아직 이미지가 하나도 없는 종류는 조회·삭제가 404 로 온다.
    그건 오류가 아니라 "없다" 는 뜻이라 빈 값으로 넘긴다."""
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", f"Bearer {tok}")
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req) as res:
            payload = res.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as e:
        if e.code == 404 and tolerate_404:
            return {}
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
            tolerate_404=True,
        )
        print(f"{kind}: {len(got.get('images', []))}장")
    print()

    if mode == "inspect":
        # edit 을 커밋하지 않고 버린다. 아무것도 바뀌지 않는다.
        call("DELETE", f"{BASE}/applications/{PACKAGE}/edits/{edit_id}", tok)
        print("읽기만 하고 edit 을 버렸다. 바뀐 것은 없다.")
        return

    full_new = FULL_DESCRIPTION_FILE.read_text(encoding="utf-8").rstrip("\n")
    listing_new = {
        "language": LANGUAGE,
        "title": TITLE,
        "shortDescription": SHORT_DESCRIPTION,
        "fullDescription": full_new,
    }
    for field, limit in LIMITS.items():
        if len(listing_new[field]) > limit:
            raise SystemExit(f"{field} 가 {len(listing_new[field])}자로 상한 {limit}자를 넘는다")

    print("── 넣을 텍스트 ──")
    for field in LIMITS:
        print(f"{field}: {len(listing_new[field])}자")
    print()

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
            tolerate_404=True,
        )
        for p in paths:
            body = p.read_bytes()
            for i, host in enumerate(UPLOAD_HOSTS):
                url = (f"{host}/applications/{PACKAGE}/edits/{edit_id}"
                       f"/images/{LANGUAGE}/{kind}?uploadType=media")
                last = i == len(UPLOAD_HOSTS) - 1
                got = call("POST", url, tok, body=body,
                           content_type="image/png", tolerate_404=not last)
                if got or last:
                    print(f"올림: {kind} ← {p.name}  ({host.split('/')[2]})")
                    break

    call(
        "PUT",
        f"{BASE}/applications/{PACKAGE}/edits/{edit_id}/listings/{LANGUAGE}",
        tok,
        body=json.dumps(listing_new).encode("utf-8"),
        content_type="application/json",
    )
    print("텍스트를 넣었다.")

    call("POST", f"{BASE}/applications/{PACKAGE}/edits/{edit_id}:commit", tok)
    print("\ncommit 했다.")


if __name__ == "__main__":
    main()
