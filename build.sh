#!/bin/bash
set -e

# Install dependencies
sudo apt-get update
sudo apt-get install -y \
  git \
  cmake \
  ninja-build \
  python3 \
  g++ \
  pkg-config \
  libx11-dev \
  libxext-dev \
  libxcb-icccm4-dev \
  libxcb-keysyms1-dev \
  libxcb-randr0-dev \
  libxcb-render0-dev \
  libxcb-shape0-dev \
  libxcb-xfixes0-dev \
  libxcb-xinerama0-dev \
  libxcb-xkb-dev \
  libxkbcommon-dev \
  libxkbcommon-x11-dev

# Clone aseprite repo
if [ ! -d aseprite ]; then
  git clone --recursive --tags https://github.com/aseprite/aseprite.git aseprite
else
  cd aseprite && git fetch --tags && cd ..
fi

# Get latest version
if [ -z "$ASEPRITE_VERSION" ]; then
  ASEPRITE_VERSION=$(git -C aseprite tag --sort=creatordate | tail -1)
fi

echo "Building $ASEPRITE_VERSION"

# Update to selected tag
cd aseprite
git clean -fdx
git submodule foreach --recursive git clean -xfd
git fetch --depth=1 --no-tags origin "$ASEPRITE_VERSION:refs/remotes/origin/$ASEPRITE_VERSION"
git reset --hard "origin/$ASEPRITE_VERSION"
git submodule update --init --recursive
cd ..

# Update version
python3 -c "
with open('aseprite/src/ver/CMakeLists.txt', 'r') as f:
    content = f.read()
content = content.replace('1.x-dev', '$ASEPRITE_VERSION'[1:])
with open('aseprite/src/ver/CMakeLists.txt', 'w') as f:
    f.write(content)
"

# Download skia (Linux version)
if [ -f aseprite/laf/misc/skia-tag.txt ]; then
  SKIA_VERSION=$(cat aseprite/laf/misc/skia-tag.txt)
else
  SKIA_VERSION="m102-861e4743af"
fi

if [ ! -d "skia-$SKIA_VERSION" ]; then
  mkdir "skia-$SKIA_VERSION"
  cd "skia-$SKIA_VERSION"
  curl -sfLO "https://github.com/aseprite/skia/releases/download/$SKIA_VERSION/Skia-Linux-Release-x64.zip"
  unzip -q "Skia-Linux-Release-x64.zip"
  cd ..
fi

# Build aseprite
rm -rf build
cmake \
  -G Ninja \
  -S aseprite \
  -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DLAF_BACKEND=skia \
  -DSKIA_DIR="$(pwd)/skia-$SKIA_VERSION" \
  -DSKIA_LIBRARY_DIR="$(pwd)/skia-$SKIA_VERSION/out/Release-x64"

ninja -C build

# Create output folder
mkdir -p "aseprite-$ASEPRITE_VERSION"
echo "# This file is here so Aseprite behaves as a portable program" > "aseprite-$ASEPRITE_VERSION/aseprite.ini"
cp -r aseprite/docs "aseprite-$ASEPRITE_VERSION/"
cp build/bin/aseprite "aseprite-$ASEPRITE_VERSION/"
cp -r build/bin/data "aseprite-$ASEPRITE_VERSION/"

# For GitHub Actions
if [ -n "$GITHUB_WORKFLOW" ]; then
  mkdir -p github
  mv "aseprite-$ASEPRITE_VERSION" github/
  echo "ASEPRITE_VERSION=$ASEPRITE_VERSION" >> "$GITHUB_OUTPUT"
fi
