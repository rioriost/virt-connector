class VirtConnector < Formula
  desc "Link macOS display sleep, wake, and shutdown events to Shortcuts"
  homepage "https://github.com/rioriost/Virt-Connector"
  url "https://github.com/rioriost/Virt-Connector/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PUT_SHA256_HERE"
  license "MIT"
  head "https://github.com/rioriost/Virt-Connector.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on macos: :ventura

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/virt-connector"
    bin.install ".build/release/virt-connectord"
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/virt-connector help")
  end
end
