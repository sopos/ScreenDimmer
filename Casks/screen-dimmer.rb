cask "screen-dimmer" do
  version "1.5.0"
  sha256 "b848101ff9d833bd7c69a18a093ec8756ce1d77b5b142b8414ef2ae89997f945"

  url "https://github.com/sopos/ScreenDimmer/releases/download/v#{version}/ScreenDimmer.zip"
  name "ScreenDimmer"
  desc "Fake black screen saver for MDM-managed Macs that block display sleep"
  homepage "https://github.com/sopos/ScreenDimmer"

  depends_on macos: :ventura

  app "ScreenDimmer.app"

  postflight do
    system_command "/usr/bin/xattr",
      args: ["-dr", "com.apple.quarantine", "#{appdir}/ScreenDimmer.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.local.ScreenDimmer.plist",
  ]
end
