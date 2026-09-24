# typed: strict
# frozen_string_literal: true

require "formulary"
require "extend/ENV/shared"
require "minitest/autorun"
require "open3"

# Exercise the formula without building or installing the app.
class GhosttyForkTest < Minitest::Test
  sig { void }
  def test_source_pin
    formula = Formulary.factory(Pathname(__FILE__).dirname/"../Formula/ghostty-fork.rb")
    stable = formula.stable
    raise "Expected a stable source pin" unless stable

    assert_equal ["1.3.1-opacityfix.3", GitDownloadStrategy,
                  { revision: "a7ca62e8f50c2be41acce3e4009f7ec40ecd38e0" }],
                 [formula.version.to_s, stable.downloader.class, stable.specs]
  end

  sig { void }
  def test_build_tools
    original_env = ENV.to_h
    ENV.extend(SharedEnvExtension)
    formula = Formulary.factory(Pathname(__FILE__).dirname/"../Formula/ghostty-fork.rb")
    formula.singleton_class.class_eval { public :configure_build_tools }
    Dir.mktmpdir("ghostty-formula-test") do |directory|
      formula.buildpath = Pathname(directory)
      tools = Pathname(directory)/".homebrew-tools"
      tools.mkpath
      formula.public_method(:configure_build_tools).call
      selector = tools/"xcrun"
      assert_predicate selector, :executable?
      assert_equal tools.to_s, ENV.fetch("PATH").split(File::PATH_SEPARATOR).first
      assert_equal "#!/bin/sh\nexec /usr/bin/xcodebuild -IDEPackageSupportDisableManifestSandbox=1 \"$@\"\n",
                   (tools/"xcodebuild").read
      assert system("/bin/bash", "-n", selector.to_s)

      # Substitute only external boundaries in a disposable copy of the generated selector.
      sdk = Pathname(directory)/"MacOSX26.5.sdk"
      sdk.mkpath
      fake_xcrun = Pathname(directory)/"apple-xcrun"
      fake_xcrun.write <<~SH
        #!/bin/bash
        set -eu
        if [[ $# == 3 && $1 == --sdk && $2 == macosx && $3 == --show-sdk-version ]]; then
          printf '%s\\n' "$TEST_SDK_VERSION"
          exit "${TEST_SDK_STATUS:-0}"
        fi
        printf '<%s>\\n' "$@"
        exit "${TEST_DELEGATE_STATUS:-0}"
      SH
      fake_xcrun.chmod 0755
      isolated_selector = tools/"isolated-xcrun"
      isolated_selector.write selector.read.gsub("/usr/bin/xcrun", fake_xcrun.to_s)
                                      .gsub("/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk", sdk.to_s)
      isolated_selector.chmod 0755

      ENV["TEST_SDK_VERSION"] = "27.0"
      output, error, status = Open3.capture3(isolated_selector.to_s, "--sdk", "macosx", "--show-sdk-path")
      assert_equal ["#{sdk}\n", "", 0], [output, error, status.exitstatus]
      [[], %w[--sdk iphoneos --show-sdk-path], %w[--sdk macosx --show-sdk-version],
       %w[--show-sdk-path --sdk macosx], %w[--sdk macosx --show-sdk-path --verbose],
       ["--find", "a tool with spaces"], %w[--sdk macosx --find metal], %w[--sdk macosx --find metallib],
       %w[--sdk macosx --find clang++], %w[--sdk macosx --find actool]]
        .each do |args|
          ENV["TEST_DELEGATE_STATUS"] = "7"
          delegated_output, delegated_error, delegated_status = Open3.capture3(isolated_selector.to_s, *args)
          expected = args.empty? ? "<>\n" : args.map { |arg| "<#{arg}>\n" }.join
          expected = "27.0\n" if args == %w[--sdk macosx --show-sdk-version]
          assert_equal [expected, "", (args == %w[--sdk macosx --show-sdk-version]) ? 0 : 7],
                       [delegated_output, delegated_error, delegated_status.exitstatus], args.inspect
        end
      ENV.delete("TEST_DELEGATE_STATUS")

      sdk.rmdir
      output, error, status = Open3.capture3(isolated_selector.to_s, "--sdk", "macosx", "--show-sdk-path")
      assert_equal "", output
      refute_predicate status, :success?
      assert_includes error, "MacOSX26.5.sdk"

      ENV["TEST_SDK_VERSION"] = "26.5"
      output, error, status = Open3.capture3(isolated_selector.to_s, "--sdk", "macosx", "--show-sdk-path")
      assert_equal ["<--sdk>\n<macosx>\n<--show-sdk-path>\n", "", 0], [output, error, status.exitstatus]

      ENV["TEST_SDK_STATUS"] = "9"
      output, error, status = Open3.capture3(isolated_selector.to_s, "--sdk", "macosx", "--show-sdk-path")
      assert_equal ["", "", 9], [output, error, status.exitstatus]
    end
  ensure
    ENV.replace(original_env) if original_env
  end
end
