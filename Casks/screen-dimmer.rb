cask "screen-dimmer" do
  version "1.6.0"
  sha256 "c5293c7f657e76ce42511fca87a121f87d9ba60ea63ded529c7d182d65f62e72"

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
