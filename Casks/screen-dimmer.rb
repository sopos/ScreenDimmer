cask "screen-dimmer" do
  version "1.3.0"
  sha256 "aed6865708e503772fa68e17a41f8a424830adf59ef3bd6aa2f765ef590d7b99"

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
