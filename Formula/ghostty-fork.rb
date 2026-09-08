class GhosttyFork < Formula
  desc "Ghostty with corrected macOS colored-cell transparency"
  homepage "https://github.com/kessriga/ghostty"
  url "https://github.com/kessriga/ghostty.git", revision: "662ee3b4830b2777b3c4c267eaf502c7cc46c8dc"
  version "1.3.1-opacityfix.2"
  license "MIT"

  keg_only "activation must first migrate the official Ghostty cask"

  depends_on "gettext" => :build
  depends_on "llvm@20" => :build
  depends_on "pandoc" => :build
  depends_on xcode: ["26.0", :build]
  depends_on "zig@0.15" => :build
  depends_on :macos

  def install
    configure_build_tools
    system "bash", "macos/build-local.sh", version.to_s
    prefix.install "zig-out/Ghostty.app"

    app = prefix/"Ghostty.app"
    info = app/"Contents/Info.plist"
    {
      "GhosttyForkSource"          => "kessriga/ghostty",
      "GhosttyForkRevision"        => stable.specs.fetch(:revision),
      "GhosttyForkVersion"         => version.to_s,
      "CFBundleShortVersionString" => version.to_s,
    }.each do |key, value|
      system "/usr/bin/plutil", "-replace", key, "-string", value, info
    end
    %w[SUEnableAutomaticChecks SUAutomaticallyUpdate SUAllowsAutomaticUpdates].each do |key|
      system "/usr/bin/plutil", "-replace", key, "-bool", "false", info
    end
    (bin/"ghostty").write <<~SH
      #!/bin/sh
      exec /Applications/Ghostty.app/Contents/MacOS/ghostty "$@"
    SH
    man1.install_symlink app/"Contents/Resources/man/man1/ghostty.1"
    man5.install_symlink app/"Contents/Resources/man/man5/ghostty.5"
    bash_completion.install_symlink app/"Contents/Resources/bash-completion/completions/ghostty.bash" => "ghostty"
    fish_completion.install_symlink app/"Contents/Resources/fish/vendor_completions.d/ghostty.fish"
    zsh_completion.install_symlink app/"Contents/Resources/zsh/site-functions/_ghostty"
  end

  def post_install
    app = prefix/"Ghostty.app"
    system "/usr/bin/codesign", "--force", "--deep", "--sign", "-", "--options=0", app
    system "/usr/bin/codesign", "--verify", "--deep", "--strict", app
  end

  def caveats
    <<~EOS
      This is a locally signed fork build, not an upstream release.
      Building does not replace the running Ghostty app.

      From your Dotfiles checkout, deploy `auto-update = off`, quit Ghostty,
      then run `mise run activate-ghostty --replace-existing`.
      Activation backs up the existing app, migrates the official cask,
      links and pins this keg, and points /Applications/Ghostty.app at the fork.
      For later versions, quit Ghostty and use `mise run update-ghostty`.
    EOS
  end

  test do
    app = prefix/"Ghostty.app"
    assert_match version.to_s, shell_output("#{app}/Contents/MacOS/ghostty +version")
    assert_equal "com.mitchellh.ghostty",
                 shell_output("/usr/bin/plutil -extract CFBundleIdentifier raw '#{app}/Contents/Info.plist'").strip
    assert_equal stable.specs.fetch(:revision),
                 shell_output("/usr/bin/plutil -extract GhosttyForkRevision raw '#{app}/Contents/Info.plist'").strip
    system "/usr/bin/codesign", "--verify", "--deep", "--strict", app
  end

  private

  def configure_build_tools
    ENV["GHOSTTY_ZIG"] = formula_opt_bin("zig@0.15")/"zig"
    ENV["GHOSTTY_LIBTOOL"] = formula_opt_bin("llvm@20")/"llvm-libtool-darwin"
    ENV["GHOSTTY_MSGFMT"] = formula_opt_bin("gettext")/"msgfmt"
    ENV["ZIG_GLOBAL_CACHE_DIR"] = buildpath/".zig-global-cache"
    tools = buildpath/".homebrew-tools"
    (tools/"xcodebuild").write <<~SH
      #!/bin/sh
      exec /usr/bin/xcodebuild -IDEPackageSupportDisableManifestSandbox=1 "$@"
    SH
    (tools/"xcodebuild").chmod 0755
    ENV.prepend_path "PATH", tools
  end
end
