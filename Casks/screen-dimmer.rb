cask "screen-dimmer" do
  version "1.6.1"
  sha256 "c14646633c190e39017b0ccdfbc566567cc61fcc4fdbd95b48a5ceea27d90255"

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
