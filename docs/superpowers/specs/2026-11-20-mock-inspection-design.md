# Mock inspection and consistent scenario lists — design (0.5.0)

## Intent

Make it easy to see what each mock does, so you turn the right one on or
off, in both the `deceiver_flutter` panel and the DevTools extension. And
show scenarios the same way in both.

## Approaches considered

How to know what a mock returns without calling it:

- **Metadata attached to the builder function (chosen).** The response
  helpers attach their status code, headers and body to the closure they
  return, via an `Expando`. Registration reads it into the mock. No change
  to the helpers' API or `DeceiverResponseBuilder`.
- Helpers return a callable class: rejected, doesn't fit the function type
  and can break code that composes builders.
- Run the builder with a fake request: rejected, advances
  `sequentialResponse` and lacks path parameters.

## Design

### Core

- `DeceiverResponseInfo` with `kind` (json, error, empty, sequential,
  random, custom), `statusCode`, `headers`, `body`, `variants`, and a short
  `summary` (`200 · JSON · 2 items`, `500 · error: "Server error"`,
  `204 · empty`, `sequence: 200 → 500`, `custom response`).
- `DeceiverData.responseInfo`, set on registration from the builder the
  user passed. Custom builders are `custom`.
- `getState` of the service extensions includes the info; long bodies are
  truncated.

### Panel and DevTools

- Every mock row shows the summary. Clicking a mock shows its details:
  description, base URL, base or scenario, enabled, status, headers, body
  (JSON formatted) and the variants of a sequence. Only the switch toggles.
  - DevTools: the right pane becomes "Details", for the selected request or
    mock.
  - Panel: a bottom sheet.
- Same order in both: mocks of the active scenario, base mocks, then the
  other scenarios collapsed.
- A base mock overridden by an enabled mock of the active scenario with the
  same description is labelled "overridden". Approximate: doesn't work for
  `on.match`.

### Out of scope

- Describing custom builders (`describedResponse('…', builder)`).
- Listing the requests a mock answered.
