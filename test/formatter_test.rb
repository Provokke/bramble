require 'test_helper'

class FormatterTest < Minitest::Test
  def item(id, text, **options)
    Bramble::Item.new(id: id, text: text, created: TODAY, **options)
  end

  def test_empty_list_has_a_message
    assert_equal ['nothing here'], Bramble::Formatter.list([], TODAY)
  end

  def test_row_layout
    row = Bramble::Formatter.row(item(3, 'buy milk', tags: ['home'], due: TODAY + 1, priority: :high), TODAY, 2)

    assert_equal ' 3 [ ] ! 2026-11-20 buy milk #home', row
  end

  def test_rows_without_a_due_date_keep_columns_aligned
    row = Bramble::Formatter.row(item(1, 'plain'), TODAY, 1)

    assert_equal "1 [ ]#{' ' * 14}plain", row
  end

  def test_marks
    assert_equal '[x]', Bramble::Formatter.mark(item(1, 'x', done_on: TODAY))
    assert_equal '[ ]', Bramble::Formatter.mark(item(1, 'x'))
    assert_equal '(n)', Bramble::Formatter.mark(item(1, 'x', kind: :note))
  end

  def test_overdue_rows_are_flagged
    row = Bramble::Formatter.row(item(1, 'late', due: TODAY - 2), TODAY, 1)

    assert_match(/\(overdue\)\z/, row)
  end

  def test_sort_puts_overdue_then_soonest_then_priority
    items = [
      item(1, 'later', due: TODAY + 5),
      item(2, 'undated'),
      item(3, 'late', due: TODAY - 1),
      item(4, 'soon', due: TODAY + 1),
      item(5, 'soon but important', due: TODAY + 1, priority: :high)
    ]

    assert_equal [3, 5, 4, 1, 2], Bramble::Formatter.sort(items, TODAY).map(&:id)
  end

  def test_sort_puts_notes_and_done_items_last
    items = [
      item(1, 'note', kind: :note),
      item(2, 'finished', done_on: TODAY),
      item(3, 'open')
    ]

    assert_equal [3, 2, 1], Bramble::Formatter.sort(items, TODAY).map(&:id)
  end

  def test_ids_are_right_aligned_to_the_widest
    lines = Bramble::Formatter.list([item(9, 'a'), item(10, 'b')], TODAY)

    assert lines.any? { |line| line.start_with?(' 9 ') }
    assert lines.any? { |line| line.start_with?('10 ') }
  end

  def test_detail_lists_set_fields_only
    lines = Bramble::Formatter.detail(item(2, 'x', tags: %w[a b], due: TODAY + 1), TODAY)

    assert_includes lines, 'due:      2026-11-20'
    assert_includes lines, 'tags:     a, b'
    refute(lines.any? { |line| line.start_with?('done:') })
  end

  def test_tag_counts_sort_by_count_then_name
    items = [item(1, 'a', tags: %w[b c]), item(2, 'b', tags: %w[c a]), item(3, 'c', tags: ['c'])]

    assert_equal ['c  3', 'a  1', 'b  1'], Bramble::Formatter.tag_counts(items)
    assert_equal ['no tags'], Bramble::Formatter.tag_counts([item(1, 'a')])
  end

  def test_stats_counts
    items = [
      item(1, 'open'),
      item(2, 'late', due: TODAY - 1),
      item(3, 'done', done_on: TODAY),
      item(4, 'note', kind: :note)
    ]

    assert_equal ['open:    2', 'done:    1', 'overdue: 1', 'notes:   1'], Bramble::Formatter.stats(items, TODAY)
  end
end
