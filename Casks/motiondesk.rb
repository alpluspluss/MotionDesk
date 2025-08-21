cask "motiondesk" do
  version "0.2.1"
  sha256 "787cf064ac755ca8b86858aafe54580dc3348d94634487939e76fed61b8f52a8"

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
