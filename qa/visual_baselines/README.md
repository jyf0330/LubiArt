# Visual regression baselines

`tests/qa/ui_regression.gd` stores 480×270 deterministic keyframes under a
platform directory:

- `macos/`
- `linux/`
- `windows/`

Create or intentionally refresh the current platform baseline with:

```bash
python3 tools/qa/run_qa.py --suite visual --update-baselines
```

Normal runs never rewrite a baseline. They save the current capture and a
high-contrast `*.diff.png` only when the root-mean-square or changed-pixel ratio
exceeds the configured tolerance. A small changed-pixel allowance absorbs
late-clearing combat numbers and antialiasing without allowing broad layout
changes. Review baseline changes like source changes; never update them merely
to silence a failure.
