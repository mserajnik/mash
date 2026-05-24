# SPDX-FileCopyrightText: 2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

class Mash < Formula
  desc "Simple Git-based WoW addon manager for old clients"
  homepage "https://github.com/mserajnik/mash"
  license "AGPL-3.0-or-later"
  head "https://github.com/mserajnik/mash.git", branch: "master"

  def install
    bin.install "bin/mash"
  end

  test do
    assert_match "mash", shell_output("#{bin}/mash --help")
  end
end
