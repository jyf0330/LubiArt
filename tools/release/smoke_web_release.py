#!/usr/bin/env python3
"""Serve and boot the exported Web build in Chromium."""

from __future__ import annotations

import argparse
import contextlib
import http.server
import json
import socket
import threading
import time
from pathlib import Path


class ReleaseHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        super().end_headers()

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def copyfile(self, source: object, outputfile: object) -> None:
        try:
            super().copyfile(source, outputfile)
        except (BrokenPipeError, ConnectionResetError):
            # Chromium may cancel a speculative or superseded WASM request.
            return


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("build_dir", nargs="?", default="build/web")
    parser.add_argument("--timeout", type=float, default=45.0)
    parser.add_argument("--evidence", default="output/validation/web-release-smoke.json")
    return parser.parse_args()


def free_port() -> int:
    with contextlib.closing(socket.socket()) as candidate:
        candidate.bind(("127.0.0.1", 0))
        return int(candidate.getsockname()[1])


def main() -> int:
    options = parse_args()
    build_dir = Path(options.build_dir).resolve()
    required = [build_dir / name for name in ("index.html", "index.js", "index.wasm", "index.pck", "SHA256SUMS")]
    missing = [str(path) for path in required if not path.is_file() or path.stat().st_size == 0]
    if missing:
        raise SystemExit("Missing release artifacts: " + ", ".join(missing))

    try:
        from playwright.sync_api import sync_playwright
    except ImportError as error:
        raise SystemExit("Playwright is required: python3 -m pip install playwright") from error

    port = free_port()
    handler = lambda *args, **kwargs: ReleaseHandler(*args, directory=str(build_dir), **kwargs)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://127.0.0.1:{port}/index.html"
    errors: list[str] = []
    started = time.monotonic()
    canvas_count = 0
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True)
            page = browser.new_page(viewport={"width": 1920, "height": 1080})
            page.on("pageerror", lambda error: errors.append(f"pageerror:{error}"))
            page.on("console", lambda message: errors.append(f"console:{message.type}:{message.text}") if message.type == "error" else None)
            response = page.goto(url, wait_until="domcontentloaded", timeout=int(options.timeout * 1000))
            if response is None or not response.ok:
                errors.append(f"http:{response.status if response else 'no-response'}")
            deadline = time.monotonic() + options.timeout
            while time.monotonic() < deadline:
                canvas_count = page.locator("canvas").count()
                if canvas_count > 0 and page.locator("canvas").first.is_visible():
                    break
                page.wait_for_timeout(250)
            else:
                errors.append("visible-canvas-timeout")
            browser.close()
    finally:
        server.shutdown()
        server.server_close()

    evidence = {
        "schema": "ysbzs.web-release-smoke.v1",
        "url": url,
        "buildDir": str(build_dir),
        "durationSeconds": round(time.monotonic() - started, 3),
        "canvasCount": canvas_count,
        "errors": errors,
        "status": "passed" if not errors else "failed",
    }
    evidence_path = Path(options.evidence)
    evidence_path.parent.mkdir(parents=True, exist_ok=True)
    evidence_path.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("WEB_RELEASE_SMOKE_FAIL " + json.dumps(errors, ensure_ascii=False))
        return 1
    print(f"WEB_RELEASE_SMOKE_OK canvas={canvas_count} evidence={evidence_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
