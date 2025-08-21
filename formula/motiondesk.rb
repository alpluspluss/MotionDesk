cask "motiondesk" do
  version "0.1.0"
  sha256 "INSERT_SHA256_HASH_HERE"

  url "https://github.com/alpluspluss/MotionDesk/releases/download/v#{version}/MotionDesk-v#{version}.dmg"
  name "MotionDesk"
  desc "Lightweight wallpaper management daemon for macOS"
  homepage "https://github.com/alpluspluss/MotionDesk"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "MotionDesk.app"

  postflight do
    system_command "/usr/bin/open", args: ["-a", "MotionDesk"]
  end

  uninstall_postflight do
    system_command "/usr/bin/killall", args: ["MotionDesk"], sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.motiondesk.app.plist",
    "~/Library/Application Support/MotionDesk",
  ]
end
