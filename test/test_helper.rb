require 'minitest/autorun'
require 'tmpdir'
require 'stringio'
require 'bramble'

TODAY = Date.new(2026, 11, 19)

module TempStore
  def setup
    super
    @dir = Dir.mktmpdir('bramble-test')
    @path = File.join(@dir, 'items.txt')
  end

  def teardown
    FileUtils.remove_entry(@dir)
    super
  end
end

module CLIHelper
  include TempStore

  def bramble(*args)
    out = StringIO.new
    err = StringIO.new
    code = Bramble::CLI.new(out: out, err: err, env: { 'BRAMBLE_FILE' => @path }, today: -> { TODAY }).run(args)
    [code, out.string, err.string]
  end

  def bramble_ok(*args)
    code, out, err = bramble(*args)
    assert_equal 0, code, "bramble #{args.join(' ')} failed: #{err}"
    out
  end
end
