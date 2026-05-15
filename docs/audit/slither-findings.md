# Slither Findings

## Command

```bash
slither . --filter-paths "lib|node_modules|out|cache" --exclude solc-version
```

## Latest Local Result

Date: 2026-05-08

Result:

```text
INFO:Slither:. analyzed (66 contracts with 100 detectors), 0 result(s) found
```

## High and Medium Findings

| Severity | Count | Status |
| --- | ---: | --- |
| High | 0 | Clean |
| Medium | 0 | Clean |

## Notes

The CI workflow also runs Slither through `crytic/slither-action`. The local command filters generated dependencies and build artifacts so that the result focuses on project contracts.
