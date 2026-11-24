FROM plumos-rk3566-bubble-tools:ec81d42
RUN apt-get update && apt-get install -y --no-install-recommends \
    bc bison device-tree-compiler flex gcc-aarch64-linux-gnu libssl-dev patch python3-pyelftools \
    && rm -rf /var/lib/apt/lists/*
