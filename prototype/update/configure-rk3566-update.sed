# Scope these substitutions to the pinned updater and its package builder.
s/^DEVICE_ID = "gkd-bubble"$/DEVICE_ID = "rk3566"/
s/^DEVICE_ID = "rg353m"$/DEVICE_ID = "rk3566"/
s/^VENDOR_RUNTIME = "bubble-stockos-r1"$/VENDOR_RUNTIME = "rk3566-plumos-r1"/
s/plumos-bubble-update-public\.pem/plumos-rk3566-update-public.pem/g
s/plumos-bubble-\*\.tar\.gz/plumos-rk3566-runtime-*.tar.gz/g
s/plumos-bubble-{args.type}-{args.version}/plumos-rk3566-{args.type}-{args.version}/g
s/PLUMOS_BUBBLE_UPDATE_SIGNING_KEY/PLUMOS_RK3566_UPDATE_SIGNING_KEY/g
s/artifacts\/update-signing\/plumos-bubble-ed25519-private.pem/artifacts\/update-signing\/rk3566-ed25519-private.pem/g
