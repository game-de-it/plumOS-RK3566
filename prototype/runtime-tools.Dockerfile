FROM plumos-rk3566-bubble-tools:ec81d42
RUN apt-get update && apt-get install -y --no-install-recommends \
    libboost-locale1.74.0 libboost-filesystem1.74.0 libboost-atomic1.74.0 \
    libboost-chrono1.74.0 libboost-thread1.74.0 libboost-date-time1.74.0 \
    libboost-system1.74.0 libfmt9 libluajit-5.1-2 libspeexdsp1 libxmp4 \
    libopenal1 libmodplug1 libsndfile1 libsdl1.2debian libsdl2-gfx-1.0-0 \
    libsdl2-image-2.0-0 libsdl2-ttf-2.0-0 libnsl2 libgif7 libsqlite3-0 \
    unzip ca-certificates openssh-sftp-server samba tzdata && rm -rf /var/lib/apt/lists/*
