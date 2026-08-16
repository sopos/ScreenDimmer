cask "screen-dimmer" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256"

  url "https://github.com/sopos/ScreenDimmer/releases/download/v#{version}/ScreenDimmer.zip"
  name "ScreenDimmer"
  desc "Fake black screen saver for MDM-managed Macs that block display sleep"
  homepage "https://github.com/sopos/ScreenDimmer"

  depends_on macos: ">= :ventura"

  app "ScreenDimmer.app"

  zap trash: [
    "~/Library/Preferences/com.local.ScreenDimmer.plist",
  ]
end
