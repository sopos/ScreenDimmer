cask "screen-dimmer" do
  version "1.6.0"
  sha256 "77f8f6f2ce2304599bc58248f998941bd7346ddffc471bbbe7eceae99dde0346"

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
