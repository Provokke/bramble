require 'test_helper'

class CLITest < Minitest::Test
  include CLIHelper

  def test_add_creates_a_todo_with_everything_parsed
    assert_equal "added todo 1\n", bramble_ok('add', 'buy', 'milk', '#home', '@tomorrow', '!high')

    item = Bramble::Store.new(@path).find(1)
    assert_equal 'buy milk', item.text
    assert_equal ['home'], item.tags
    assert_equal TODAY + 1, item.due
    assert_equal :high, item.priority
    assert_equal TODAY, item.created
  end

  def test_note_creates_a_note
    assert_equal "added note 1\n", bramble_ok('note', 'wifi password is on the fridge')

    assert_predicate Bramble::Store.new(@path).find(1), :note?
  end

  def test_add_with_no_text_is_a_usage_error
    code, _out, err = bramble('add', '#only-a-tag')

    assert_equal 2, code
    assert_match(/nothing to add/, err)
  end

  def test_list_shows_open_items
    bramble_ok('add', 'first')
    bramble_ok('add', 'second', '!high')
    bramble_ok('note', 'a thought')
    out = bramble_ok('list')

    assert_equal 3, out.lines.size
    assert_match(/second/, out.lines.first)
    assert_match(/\(n\).*a thought/, out.lines.last)
  end

  def test_list_hides_done_items_unless_asked
    bramble_ok('add', 'finished one')
    bramble_ok('add', 'still open')
    bramble_ok('done', '1')

    refute_match(/finished one/, bramble_ok('list'))
    assert_match(/finished one/, bramble_ok('list', '--all'))
  end

  def test_list_filters
    bramble_ok('add', 'a', '#work')
    bramble_ok('add', 'b', '#home')
    bramble_ok('note', 'c', '#work')
    bramble_ok('add', 'late', '@2026-11-01')

    assert_equal 2, bramble_ok('list', '--tag', 'work').lines.size
    assert_equal 1, bramble_ok('list', '-t', '#home').lines.size
    assert_equal 1, bramble_ok('list', '--notes').lines.size
    assert_equal 3, bramble_ok('list', '--todos').lines.size
    assert_match(/late/, bramble_ok('list', '--overdue'))
    assert_equal 1, bramble_ok('list', '--overdue').lines.size
  end

  def test_list_of_nothing
    assert_equal "nothing here\n", bramble_ok('list')
  end

  def test_ls_is_an_alias_for_list
    bramble_ok('add', 'x')

    assert_equal bramble_ok('list'), bramble_ok('ls')
  end

  def test_done_and_undo
    bramble_ok('add', 'task')

    assert_equal "done 1\n", bramble_ok('done', '1')
    assert_equal TODAY, Bramble::Store.new(@path).find(1).done_on
    assert_equal "reopened 1\n", bramble_ok('undo', '1')
    refute_predicate Bramble::Store.new(@path).find(1), :done?
  end

  def test_done_twice_keeps_the_first_date
    bramble_ok('add', 'task')
    bramble_ok('done', '1')
    store = Bramble::Store.new(@path)
    store.update(1) { |item| item.done_on = TODAY - 3 }
    bramble_ok('done', '1')

    assert_equal TODAY - 3, store.find(1).done_on
  end

  def test_done_takes_several_ids
    bramble_ok('add', 'a')
    bramble_ok('add', 'b')

    assert_equal "done 1\ndone 2\n", bramble_ok('done', '1', '2')
  end

  def test_done_on_a_note_is_refused
    bramble_ok('note', 'just a note')
    code, _out, err = bramble('done', '1')

    assert_equal 2, code
    assert_match(/is a note/, err)
  end

  def test_missing_id_exits_one
    code, _out, err = bramble('done', '42')

    assert_equal 1, code
    assert_match(/no item with id 42/, err)
  end

  def test_non_numeric_id_is_a_usage_error
    code, _out, err = bramble('rm', 'abc')

    assert_equal 2, code
    assert_match(/not an id/, err)
  end

  def test_rm_deletes
    bramble_ok('add', 'a')
    bramble_ok('add', 'b')

    assert_equal "removed 1\n", bramble_ok('rm', '1')
    assert_equal ['b'], Bramble::Store.new(@path).all.map(&:text)
  end

  def test_edit_replaces_text_and_merges_the_rest
    bramble_ok('add', 'old', '#a', '@today')
    bramble_ok('edit', '1', 'new', 'text', '#b', '!high')

    item = Bramble::Store.new(@path).find(1)
    assert_equal 'new text', item.text
    assert_equal %w[a b], item.tags
    assert_equal TODAY, item.due
    assert_equal :high, item.priority
  end

  def test_edit_can_change_only_the_date
    bramble_ok('add', 'keep me')
    bramble_ok('edit', '1', '@+2d')

    item = Bramble::Store.new(@path).find(1)
    assert_equal 'keep me', item.text
    assert_equal TODAY + 2, item.due
  end

  def test_edit_with_nothing_to_change
    bramble_ok('add', 'x')
    code, _out, err = bramble('edit', '1')

    assert_equal 2, code
    assert_match(/nothing to change/, err)
  end

  def test_show_prints_details
    bramble_ok('add', 'detailed', '#x', '@2026-12-01')
    out = bramble_ok('show', '1')

    assert_match(/text:     detailed/, out)
    assert_match(/due:      2026-12-01/, out)
  end

  def test_search_requires_every_word_and_checks_tags
    bramble_ok('add', 'call the plumber', '#house')
    bramble_ok('add', 'call mum')
    bramble_ok('note', 'plumber quote was 300')

    assert_equal 2, bramble_ok('search', 'plumber').lines.size
    assert_equal 1, bramble_ok('search', 'call', 'plumber').lines.size
    assert_equal 1, bramble_ok('search', 'HOUSE').lines.size
    assert_equal "nothing here\n", bramble_ok('search', 'zebra')
  end

  def test_tags_and_stats
    bramble_ok('add', 'a', '#x')
    bramble_ok('add', 'b', '#x', '#y', '@2026-01-01')
    bramble_ok('note', 'n')
    bramble_ok('done', '1')

    assert_equal "x  2\ny  1\n", bramble_ok('tags')
    assert_equal "open:    1\ndone:    1\noverdue: 1\nnotes:   1\n", bramble_ok('stats')
  end

  def test_clear_done
    bramble_ok('add', 'a')
    bramble_ok('add', 'b')
    bramble_ok('note', 'keep')
    bramble_ok('done', '1')

    assert_equal "cleared 1 finished todo\n", bramble_ok('clear-done')
    assert_equal ['b', 'keep'], Bramble::Store.new(@path).all.map(&:text)
    assert_equal "cleared 0 finished todos\n", bramble_ok('clear-done')
  end

  def test_file_option_overrides_the_environment
    other = File.join(@dir, 'other.txt')
    bramble_ok('--file', other, 'add', 'elsewhere')

    assert File.exist?(other)
    refute File.exist?(@path)
  end

  def test_file_option_without_a_path
    code, _out, err = bramble('list', '--file')

    assert_equal 2, code
    assert_match(/--file needs a path/, err)
  end

  def test_unknown_command_and_missing_command
    code, _out, err = bramble('frobnicate')
    assert_equal 2, code
    assert_match(/unknown command: frobnicate/, err)

    code, _out, err = bramble
    assert_equal 2, code
    assert_match(/no command given/, err)
  end

  def test_unknown_option_is_a_usage_error
    code, _out, err = bramble('list', '--bogus')

    assert_equal 2, code
    assert_match(/invalid option/, err)
  end

  def test_corrupt_file_is_reported_not_crashed
    File.write(@path, "garbage\n")
    code, _out, err = bramble('list')

    assert_equal 2, code
    assert_match(/items.txt:1:/, err)
  end

  def test_help_and_version
    assert_match(/usage: bramble/, bramble_ok('help'))
    assert_equal "bramble #{Bramble::VERSION}\n", bramble_ok('version')
  end

  def test_default_path_prefers_the_environment_variable
    assert_equal '/tmp/x.txt', Bramble::CLI.default_path('BRAMBLE_FILE' => '/tmp/x.txt', 'HOME' => '/home/me')
    assert_equal File.join('/home/me', '.bramble', 'items.txt'), Bramble::CLI.default_path('HOME' => '/home/me')
  end
end
