require 'test_helper'

class StoreTest < Minitest::Test
  include TempStore

  def store
    @store ||= Bramble::Store.new(@path)
  end

  def todo(text, **options)
    Bramble::Item.new(text: text, created: TODAY, **options)
  end

  def test_missing_file_reads_as_empty
    assert_equal [], store.all
  end

  def test_add_assigns_incrementing_ids
    assert_equal 1, store.add(todo('a')).id
    assert_equal 2, store.add(todo('b')).id
    assert_equal [1, 2], store.all.map(&:id)
  end

  def test_round_trip_keeps_every_field
    store.add(todo('full', kind: :todo, tags: %w[x y], priority: :high, due: TODAY + 2, done_on: TODAY))
    item = store.all.first

    assert_equal 'full', item.text
    assert_equal %w[x y], item.tags
    assert_equal :high, item.priority
    assert_equal TODAY + 2, item.due
    assert_equal TODAY, item.done_on
    assert_equal TODAY, item.created
    assert_equal :todo, item.kind
  end

  def test_notes_round_trip
    store.add(todo('remember', kind: :note))

    assert_predicate store.all.first, :note?
  end

  def test_awkward_text_survives
    awkward = "tab\there\nnewline \\ backslash \\n literal"
    store.add(todo(awkward))

    assert_equal awkward, store.all.first.text
    assert_equal 1, File.readlines(@path).size
  end

  def test_file_is_plain_tab_separated_text
    store.add(todo('buy milk', tags: ['home'], due: TODAY + 1))
    line = File.read(@path)

    assert_equal "1\tt\tnormal\t2026-11-19\t2026-11-20\t-\thome\tbuy milk\n", line
  end

  def test_find_and_not_found
    store.add(todo('a'))

    assert_equal 'a', store.find(1).text
    assert_raises(Bramble::NotFound) { store.find(9) }
  end

  def test_update_changes_one_item
    store.add(todo('a'))
    store.add(todo('b'))
    store.update(2) { |item| item.text = 'changed' }

    assert_equal %w[a changed], store.all.map(&:text)
  end

  def test_update_of_missing_id_leaves_the_file_alone
    store.add(todo('a'))
    before = File.read(@path)

    assert_raises(Bramble::NotFound) { store.update(5) { |item| item.text = 'x' } }
    assert_equal before, File.read(@path)
  end

  def test_failed_update_block_does_not_write
    store.add(todo('a'))

    assert_raises(RuntimeError) { store.update(1) { |item| item.text = 'half'; raise 'boom' } }
    assert_equal 'a', store.all.first.text
  end

  def test_delete_removes_an_item
    store.add(todo('a'))
    store.add(todo('b'))
    store.delete(1)

    assert_equal [2], store.all.map(&:id)
    assert_raises(Bramble::NotFound) { store.delete(1) }
  end

  def test_ids_continue_from_the_highest_remaining
    store.add(todo('a'))
    store.add(todo('b'))
    store.delete(2)

    assert_equal 2, store.add(todo('c')).id
  end

  def test_delete_where_returns_what_it_removed
    store.add(todo('a', done_on: TODAY))
    store.add(todo('b'))
    removed = store.delete_where(&:done?)

    assert_equal ['a'], removed.map(&:text)
    assert_equal ['b'], store.all.map(&:text)
  end

  def test_blank_lines_and_comments_are_ignored
    File.write(@path, "# my list\n\n1\tt\tnormal\t2026-11-19\t-\t-\t-\tonly one\n\n")

    assert_equal ['only one'], store.all.map(&:text)
  end

  def test_corrupt_line_reports_its_number
    File.write(@path, "1\tt\tnormal\t2026-11-19\t-\t-\t-\tfine\nnot a valid line\n")
    error = assert_raises(Bramble::CorruptStore) { store.all }

    assert_match(/:2: /, error.message)
  end

  def test_each_corruption_is_caught
    bad = [
      "x\tt\tnormal\t2026-11-19\t-\t-\t-\ttext",
      "1\tz\tnormal\t2026-11-19\t-\t-\t-\ttext",
      "1\tt\turgent\t2026-11-19\t-\t-\t-\ttext",
      "1\tt\tnormal\tyesterday\t-\t-\t-\ttext"
    ]
    bad.each do |line|
      File.write(@path, "#{line}\n")

      assert_raises(Bramble::CorruptStore, line) { store.all }
    end
  end

  def test_creates_missing_directories
    nested = Bramble::Store.new(File.join(@dir, 'a', 'b', 'items.txt'))
    nested.add(todo('deep'))

    assert_equal ['deep'], nested.all.map(&:text)
  end

  def test_no_temp_files_are_left_behind
    store.add(todo('a'))
    store.update(1) { |item| item.text = 'b' }

    leftovers = Dir.children(@dir).reject { |name| %w[items.txt items.txt.lock].include?(name) }
    assert_equal [], leftovers
  end

  def test_escape_and_unescape_are_inverses
    ["", "plain", "\\", "\\\\n", "a\tb\r\nc", "trailing\\"].each do |text|
      assert_equal text, Bramble::Store.unescape(Bramble::Store.escape(text))
    end
  end
end
