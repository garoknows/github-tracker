cask "tracker-for-github" do
  version "1.1.0"
  sha256 "5ab1b92416e7d1b505d054fa2cdc8ac5a46bb2ed29129094f19ac4101b14cd42"

  url "https://github.com/garoknows/github-tracker/releases/download/v#{version}/Tracker-for-GitHub-#{version}.dmg"
  name "Tracker for GitHub"
  desc "GitHub contribution graph and activity overview in the menu bar and widgets"
  homepage "https://garoknows.github.io/github-tracker/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Tracker for GitHub.app"

  uninstall quit: "io.github.garoknows.tracker"

  zap trash: [
    "~/Library/Application Scripts/io.github.garoknows.tracker",
    "~/Library/Application Scripts/io.github.garoknows.tracker.widgets",
    "~/Library/Containers/io.github.garoknows.tracker",
    "~/Library/Containers/io.github.garoknows.tracker.widgets",
    "~/Library/Group Containers/*.io.github.garoknows.tracker",
  ]
end
