ARG BASE_ALPINE="alpine:3.13"

FROM ${BASE_ALPINE} AS build

# https://github.com/qbittorrent/qBittorrent/wiki/Compilation-Alpine-Linux

ENV QBITTORRENT_TAG="release-4.6.5"
RUN apk update && apk add --no-cache git gcc g++ pkgconfig qt5-qtbase-dev qt5-qtsvg-dev boost-dev \
    cmake build-base qt5-qttools-dev libexecinfo-dev

WORKDIR /tmp

# https://github.com/google/oss-fuzz/blob/master/projects/libtorrent/Dockerfile

RUN git clone --shallow-submodules --recurse-submodules https://github.com/ninja-build/ninja.git &&\
    git clone --recurse-submodules https://github.com/qbittorrent/qBittorrent.git &&\
    git clone --recurse-submodules --shallow-submodules https://github.com/arvidn/libtorrent.git &&\
    git clone --depth 1 --single-branch --branch boost-1.76.0 --recurse-submodules https://github.com/boostorg/boost.git

RUN cd ninja && git checkout "$(git tag -l --sort=-v:refname "v*" | head -n 1)" &&\
    cmake -Wno-dev -B build \
	    -D CMAKE_CXX_STANDARD=17 \
	    -D CMAKE_INSTALL_PREFIX="/usr/local" &&\
    cmake --build build &&\
    cmake --install build
RUN cd libtorrent/ && mkdir build && cd build &&\
    cmake .. -Wno-dev -G Ninja -B build \
    -D CMAKE_BUILD_TYPE="Release" \
    -D CMAKE_CXX_STANDARD=17 \
    -D BOOST_INCLUDEDIR="/tmp/boost_1_76_0/" \
    -D CMAKE_INSTALL_LIBDIR="lib" \
    -D CMAKE_INSTALL_PREFIX="/usr/local" &&\
    cmake --build build  &&\
    cmake --install build
RUN  cd /tmp/qBittorrent &&\
    git checkout "${QBITTORRENT_TAG}" &&\
    git config pull.rebase true &&\
    ./configure PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig --disable-gui --disable-stacktrace &&\
    cmake -Wno-dev -G Ninja -B build \
    -D CMAKE_BUILD_TYPE="release" \
    -D CMAKE_CXX_STANDARD=17 \
    -D BOOST_INCLUDEDIR="/tmp/boost_1_76_0/" \
    -D CMAKE_CXX_STANDARD_LIBRARIES="/usr/lib/libexecinfo.so" \
    -D CMAKE_INSTALL_PREFIX="/usr/local" &&\
    cmake --build build &&\
    cmake --install build

RUN find / -name "libQt5core*"

FROM ${BASE_ALPINE}

ENV HOME="/home/qbittorrent"
ENV QT_QPA_PLATFORM=offscreen

RUN apk update && apk add --no-cache libgcc libstdc++ boost qt5-qtbase-dev dumb-init su-exec

COPY --from=build /usr/local/share/man/man1/qbittorrent.1 /usr/local/share/man/man1/qbittorrent.1
COPY --from=build /usr/local/lib/libtorrent-rasterbar.so.2.0 /usr/lib/libtorrent-rasterbar.so.2.0
COPY --from=build /usr/local/bin/qbittorrent /usr/local/bin/qbittorrent

RUN adduser -S -D -u 520 -g 520 -s /sbin/nologin qbittorrent \
    # Create symbolic links to simplify mounting
 && mkdir -p "${HOME}/.config/qBittorrent" \
 && mkdir -p "${HOME}/.local/share/qBittorrent" \
    # Check it works
 && su qbittorrent -s /bin/sh -c 'qbittorrent -v'

# Default configuration file.
COPY qBittorrent.conf /default/qBittorrent.conf
COPY entrypoint.sh /

VOLUME ["/home/qbittorrent"]

USER qbittorrent

EXPOSE 8080 6881

ENTRYPOINT ["dumb-init", "/entrypoint.sh"]
CMD ["qbittorrent-nox"]