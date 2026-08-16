cask "screen-dimmer" do
  version "1.1.0"
  sha256 "b3ab7472fadf367ec481bf0e0a4729fcfa3cefbada314ebbda58efa211eb28a0"

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
