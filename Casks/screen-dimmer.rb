cask "screen-dimmer" do
  version "1.6.1"
  sha256 "6055d8140eb22bab2c716a79edb0a73bfd95ead04be0ca50cbba2fd67b3ae8e9"

  url "https://github.com/sopos/ScreenDimmer/releases/download/v#{version}/ScreenDimmer.zip"
  name "ScreenDimmer"
  desc "Fake black screen saver for MDM-managed Macs that block display sleep"
  homepage "https://github.com/sopos/ScreenDimmer"

  depends_on macos: :ventura

  app "ScreenDimmer.app"

  zap trash: [
    "~/Library/Preferences/com.local.ScreenDimmer.plist",
  ]
end
