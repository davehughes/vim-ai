Refactoring notes for targeting lolmax backend
---
+ simplify interface and configuration
  + the backend should hold most configuration and models/prompts/etc. should be referenced
    by simple ids/names
  + still need http options including auth
  + still need ui-related options

  + options and dispositions
    + initial_prompt -> backend
    + openai_options -> backend
    + http_options -> keep
      + 'request_timeout': float(options['request_timeout'])
      + 'enable_auth': bool(int(options['enable_auth']))

  + since 'prompt' and 'role' are supported by the original plugin, let's leave as-is
    + though 'role' doesn't map to frontend-managed config, just a pointer to a backend role config

+ model operations as full-fledged objects, not hashes
  + can we type-check these and run tests, etc.?
  + how quickly is this just ported to lua?
    + need the vim pieces and a reasonably quick iteration loop
  + should lolmax offer a plugin interface and not just a backend server?
