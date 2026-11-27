# Accept both RK3566 and legacy release filenames in the standard inbox.
s|for path in sorted(inbox\.glob("plumos-bubble-\*\.tar\.gz")):|for path in sorted((*inbox.glob("plumos-rk3566-*.tar.gz"), *inbox.glob("plumos-bubble-*.tar.gz"))):|
