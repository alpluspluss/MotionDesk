# MotionDesk

MotionDesk is a lightweight wallpaper management daemon for macOS 
that supports static images, dynamic HEIC wallpapers, and video backgrounds with smart
power management scheme.

MotionDesk is written in Objective-C++ to be resource-efficient, running in the background without consuming significant 
CPU or memory resources, all to provide users with a seamless and visually appealing desktop experience.

MotionDesk supports various file formats, including HEIC, JPEG, PNG, and MP4, allowing users to 
set their favorite images or videos as wallpapers. See [Supported Formats](#supported-formats) for more details.

It is also worth noting that MotionDesk provides C API for developers to interact with the wallpaper management system
if they want to, e.g. write graphics interfaces for better user ergonomics.

## System Requirements

- macOS Ventura (13.0) or later
- Apple Silicon or Intel CPU
- At least 10MB of free disk space

## Installation

### Homebrew

```shell
brew tap alpluspluss/motiondesk https://github.com/alpluspluss/MotionDesk
brew instsall --cask motiondesk
```

### Manual

You can also download the latest release from [GitHub Releases](https://github.com/alpluspluss/MotionDesk/releases)
and install it by opening the `.dmg` file and dragging the app to your Applications folder. 

## Usage

MotionDesk runs as a menu bar application. After launching, you'll see the MotionDesk icon in your menu bar.

## Supported Formats

- JPEG
- PNG
- HEIC
- TIFF
- GIF
- MP4
- MOV
- AVI

## Building from Source

It is possible to build MotionDesk from source. To do so, you will need to have the following tools installed:

- macOS Ventura
- Xcode 14.0 or later
- CMake 3.30 or later
- LLVM/Clang. Apple Clang or LLVM Clang both work.

```shell
git clone https://github.com/alpluspluss/MotionDesk.git
cd MotionDesk

# install dependencies if you don't have them installed
brew install cmake ninja llvm

# on Intel Macs, you can use the default C/C++ compiler
# in usr/local/bin
cmake -B build/release \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/opt/homebrew/opt/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/homebrew/opt/llvm/bin/clang++ \
  -G Ninja

cmake --build build/release --target MotionDesk

# the built app will be located in build/release/MotionDesk.app
```

## Contributing

MotionDesk is open source software. Contributions are welcome! Simply fork the repository, 
make your changes, and submit a pull request. Contributions can be anything from typo fixes, documentations,
and bug fixes to new features and enhancements.

## License

MotionDesk is licensed under the MIT License. See the [LICENSE](LICENSE.txt) file for more details.
