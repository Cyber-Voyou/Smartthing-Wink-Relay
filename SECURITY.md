# Security policy

Do not open a public issue containing MQTT passwords, SmartThings tokens, hub IDs, private IP inventories or ADB keys. Rotate exposed credentials immediately. Report code vulnerabilities through GitHub private vulnerability reporting when enabled.

The driver intentionally rejects wildcard prefixes, limits packet size, clears queued commands on disconnect, never restores relay state at startup and never sends screen/reboot/exit commands. MQTT TCP on port 1883 is unencrypted; keep it on a trusted LAN or VPN.
