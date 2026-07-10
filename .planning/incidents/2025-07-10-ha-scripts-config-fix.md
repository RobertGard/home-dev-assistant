# Incident Report: Home Assistant Scripts Not Visible in Dashboard

- **Date**: 2025-07-10
- **Severity**: Medium (core HA functionality broken, no data loss)
- **Services affected**: Home Assistant Core (Docker), scripts subsystem, Lovelace UI
- **Duration**: ~2 hours (diagnosis + remediation)
- **Root cause**: Missing `!include` directive in `configuration.yaml` + compounded YAML/path/permission errors

---

## Summary

Home Assistant dashboard showed «Создайте свой первый скрипт» (Create your first script) despite `scripts.yaml` existing on the host. The system completely ignored manual file edits — the UI refused to register any scripts. Multiple failed attempts at manual YAML editing, Docker path discovery, and permission issues compounded the problem.

---

## Root Cause Analysis

### Primary Cause: Missing `!include` Directive

The `configuration.yaml` file contained:

```yaml
automation: !include automations.yaml
```

But was **missing**:

```yaml
script: !include scripts.yaml
```

Without this directive, the Home Assistant core does **not** read `scripts.yaml` at startup — the file is completely invisible to the runtime. The frontend (Lovelace UI) sees an empty scripts registry and displays the placeholder message.

This is documented in [Home Assistant's splitting configuration docs](https://www.home-assistant.io/docs/configuration/splitting_configuration/).

### Secondary Causes (Compounded the Debugging)

1. **Misdirection from Docker volume path** — The container volume mapping `./ha_config:/config` correctly binds the local directory. However, initial validation output `Testing configuration at /root/.homeassistant` created a false trail. This `/root/.homeassistant` path is used by `hass --script check_config` when no `-c` flag is given, but the actual runtime uses `/config`. Copying files to `/root/.homeassistant/` was a red herring.

2. **YAML type coercion (numeric ID as Integer vs String)** — The script ID `1720584135122` without quotes is parsed by YAML as an integer. Home Assistant requires unique entity IDs to be **strings**. Using `'1720584135122':` (single-quoted) ensures it's treated as a string.

3. **Bash `!` history expansion** — When using `echo` with double quotes to append `script: !include scripts.yaml`, bash interpreted `!include` as a history expansion command, producing `-bash: !include: event not found`. Solution: use single quotes: `echo -e '\nscript: !include scripts.yaml'`.

4. **Encoding corruption (Cyrillic)** — Writing YAML with Cyrillic `alias` values via `cat << 'EOF'` in a terminal with mismatched locale/encoding produced «кракозябры» (garbled UTF-8 sequences like `M-PM-^^M-PM-7M-PM-2...`). Home Assistant rejects files with invalid UTF-8. Solution: write metadata in English from console, localize later via browser UI.

5. **Docker permission boundaries** — Files in `./ha_config` are owned by `root` (container's internal user). Host user `main_user` cannot write without `sudo`. Using `sudo tee` bypasses this, but leaves files owned by root, potentially breaking the browser-based YAML editor. Post-fix: `sudo chown -R $USER:$USER ./ha_config/`.

6. **UI «Матрешка» bug** — Attempting to create a script via the browser's YAML editor while including the outer key (`say_on_phone:`) alongside the content caused a YAML nesting error (duplicate key). The UI parser hanged, blocking save/rename and showing timeout errors.

---

## Resolution Timeline

| Step | Action | Result |
|------|--------|--------|
| 1 | Diagnosed with `hass --script check_config` | Confirmed config syntax valid — problem was at include level, not syntax |
| 2 | Isolated false path `/root/.homeassistant` | Confirmed this is ephemeral; real runtime path is `/config` |
| 3 | Added `script: !include scripts.yaml` to configuration.yaml | Core architecture restored — HA now knows to load scripts |
| 4 | Wrote clean scripts.yaml via `sudo tee` | Valid YAML with string-quoted ID `'1720584135122'` |
| 5 | `docker compose restart homeassistant` | Core re-reads config, registers `script.say_text_on_phone` |
| 6 | Verified via browser (Ctrl+F5) | Script appears in dashboard list |
| 7 | Fixed file ownership with `chown` | Browser YAML editor can now save changes |

---

## File Changes

### `ha_config/configuration.yaml` — Added:

```yaml
script: !include scripts.yaml
```

### `ha_config/scripts.yaml` — Created:

```yaml
# Replace notify.mobile_app_YOUR_DEVICE with your actual service name.
# Find it: HA → Developer Tools → Services → search "notify.mobile_app"
'1720584135122':
  alias: Say text on phone
  description: Receives text from n8n and speaks it out
  fields:
    text_to_say:
      description: The text to be spoken
      example: Hello world
  sequence:
  - action: notify.mobile_app_YOUR_DEVICE
    data:
      message: TTS
      data:
        tts_text: '{{ text_to_say }}'
        media_stream: alarm_stream
        ttl: 0
        priority: high
        channel: TTS
```

**Note:** `notify.mobile_app_YOUR_DEVICE` is a placeholder. Each phone registered via HA Companion App gets a unique ID (e.g. `notify.mobile_app_infinix_x6731b`). The user must find their exact service name in HA UI and replace the placeholder.

---

## Verification Steps (Post-Fix)

```bash
# 1. Validate config
docker compose exec homeassistant hass --script check_config -c /config

# 2. Restart if clean
docker compose restart homeassistant

# 3. Fix ownership for UI editor access
sudo chown -R $USER:$USER ./ha_config/
sudo chmod -R 755 ./ha_config/

# 4. Open https://sixmo.ru → Scripts → Ctrl+F5
# 5. Run script via dashboard UI → phone plays TTS
# 6. Test n8n webhook POST → HA → TTS
```

---

## Lessons Learned

1. Every YAML split-out (scripts, scenes, templates, etc.) requires an **explicit `!include`** in `configuration.yaml`. A file on disk is invisible without it.
2. Always test config with `--script check_config` **before** restarting the container.
3. Write YAML metadata in English from the console; localize through the browser UI to avoid encoding issues.
4. Always quote numeric YAML keys used as Home Assistant entity IDs.
5. Use single quotes in bash to prevent `!` history expansion when writing `!include` directives.
6. After using `sudo` for file writes in Docker-mounted directories, run `chown` to restore ownership for UI-based editing.
7. The `hass --script check_config` default search path (`/root/.homeassistant`) is not the runtime config path — always specify `-c /config` for Docker installations.

---

## Related Documentation

- [Home Assistant: Splitting Configuration](https://www.home-assistant.io/docs/configuration/splitting_configuration/)
- [Home Assistant: Troubleshooting Configuration](https://www.home-assistant.io/docs/configuration/troubleshooting/)
- [Home Assistant: Scripts](https://www.home-assistant.io/docs/scripts/)
