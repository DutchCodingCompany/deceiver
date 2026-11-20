# Deceiver runtime control protocol

The `ext.deceiver.*` service extensions of a running app (debug and profile
builds). Call them with a VM service client on the isolate that created the
`Deceiver`, usually the main isolate. `ext.deceiver.help` returns this list
from the app itself.

## Parameters

All parameters are strings. `enabled` is `"true"` or `"false"`.

`instance`: every method except `help` and `getInstances` takes the id of a
Deceiver from `getInstances`. Leave it out when the app has exactly one.

## Methods

| Method | Parameters | Returns |
|---|---|---|
| `help` | | `{methods, instance, events}` |
| `getInstances` | | `{instances: [{id, name}]}` |
| `getState` | | state |
| `setEnabled` | `enabled` | state |
| `setOnlyAllowMocks` | `enabled` | state |
| `setActiveScenario` | `scenario` (leave out or empty to deactivate) | state |
| `setMockEnabled` | `enabled`; `mock` (id), or `description` and optional `scenario` | state |
| `setAllMocksEnabled` | `enabled` | state |
| `getRequests` | | `{requests: [request]}` |
| `clearRequests` | | `{requests: []}` |

`name` of an instance is the `name` given to `Deceiver(name: ...)`, else its
base URL, else `null`.

`setMockEnabled` with `description` compares case-insensitively. Without
`scenario` it looks in the base mocks; with `scenario` in that scenario.

## State

```json
{
  "instance": 0,
  "name": "Example API",
  "baseUrl": "https://api.example.com/v1",
  "enabled": true,
  "onlyAllowMocks": false,
  "maxRecordedRequests": 100,
  "activeScenario": "error",
  "mocks": [mock],
  "scenarios": [{"name": "error", "mocks": [mock]}]
}
```

`mocks` are the base mocks. The active scenario's mocks are tried before
them.

### Mock

```json
{
  "id": 12,
  "description": "GET /users",
  "enabled": true,
  "baseUrl": null,
  "response": {
    "kind": "json",
    "summary": "200 · JSON · 1 item",
    "statusCode": 200,
    "headers": {"content-type": "application/json"},
    "body": "[{\"id\":1,\"name\":\"Bilbo\"}]",
    "variants": []
  }
}
```

- `description`: method and path template (`GET /users/{id}`), the full URL
  for mocks registered with `on.at()` or a full URL, or the description given
  to `on.match()`.
- `baseUrl`: set for mocks of another API (`on.at()` or a full URL).
- `response.kind`: `json`, `error`, `empty` (made with those helpers),
  `sequential` and `random` (with `variants`, one per response), or `custom`
  (a builder of the app's own: what it returns is only known when it runs; see
  `getRequests` after it answered).
- `id`s are unique within the app run, but a mock gets a new one when the
  app registers it again (after `reset()`, or when it redefines a scenario)
  and after a restart. Prefer `description`.

## Request

```json
{
  "id": 3,
  "timestamp": 1795163971913,
  "method": "POST",
  "url": "https://api.example.com/v1/users",
  "requestHeaders": {"content-type": "application/json"},
  "requestBody": "{\"name\":\"Samwise\"}",
  "mock": {"id": 14, "description": "POST /users"},
  "statusCode": 201,
  "responseHeaders": {"content-type": "application/json"},
  "responseBody": "{\"id\":4,\"name\":\"Samwise\"}",
  "durationMicros": 1500,
  "error": null
}
```

- `mock: null`: no mock answered. The request went to the real server
  (its response is not recorded, so `statusCode` is `null`), or, with
  `error` set, strict mode rejected it.
- `error` with a mock: the mock's builder threw.
- Bodies longer than 64 KB are truncated.
- Requests are recorded in the order they were answered. At most
  `maxRecordedRequests` are kept. Requests while `enabled` is off, or outside
  the base URL, are not recorded.
- `timestamp` is milliseconds since the epoch, when the request arrived.

## Errors

Invalid parameters give a VM service error with code `-32602` (invalid
params) and a message that says what to pass, for example:

- `No mock "GET /orders" in the base mocks. Mocks there: "GET /users",
  "GET /posts". It is in scenario error: pass scenario.`
- `2 mocks "GET /users" in the base mocks, pass mock with one of the ids:
  12, 15.`
- `The app has 2 Deceivers, pass instance: 0 (API), 1 (Auth).`
- `The app has not created a Deceiver yet.`
- `No scenario defined with this name. Available: empty, error`

A VM service error `Method not found` (code `-32601`) for an
`ext.deceiver.*` method means the extensions aren't registered: no Deceiver
created yet, a release build, or another isolate.

## Events

Posted on the VM service `Extension` stream (`streamListen("Extension")`):

| `extensionKind` | `extensionData` |
|---|---|
| `deceiver:instancesChanged` | `{}` |
| `deceiver:changed` | `{instance}`: settings or mocks changed |
| `deceiver:request` | `{instance, request}`: a request was handled |
| `deceiver:requestsCleared` | `{instance}` |

Events are only posted while a client listens to the `Extension` stream.
