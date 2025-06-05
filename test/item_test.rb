require 'test_helper'

class ItemTest < Minitest::Test
  def test_defaults_to_an_open_normal_todo
    item = Bramble::Item.new(text: 'write tests', created: TODAY)

    assert item.todo?
    assert item.open?
    refute item.done?
    assert_equal :normal, item.priority
    assert_equal [], item.tags
  end

  def test_tags_are_sorted_and_unique
    item = Bramble::Item.new(text: 'x', tags: %w[b a b], created: TODAY)

    assert_equal %w[a b], item.tags
  end

  def test_rejects_unknown_kind_and_priority
    assert_raises(ArgumentError) { Bramble::Item.new(text: 'x', kind: :epic) }
    assert_raises(ArgumentError) { Bramble::Item.new(text: 'x', priority: :urgent) }
  end

  def test_done_items_are_not_open
    item = Bramble::Item.new(text: 'x', done_on: TODAY, created: TODAY)

    assert item.done?
    refute item.open?
  end

  def test_notes_are_never_open_or_overdue
    note = Bramble::Item.new(text: 'x', kind: :note, due: TODAY - 5, created: TODAY)

    assert note.note?
    refute note.open?
    refute note.overdue?(TODAY)
  end

  def test_overdue_needs_an_open_todo_with_a_past_due_date
    late = Bramble::Item.new(text: 'x', due: TODAY - 1, created: TODAY)
    on_time = Bramble::Item.new(text: 'x', due: TODAY, created: TODAY)
    finished = Bramble::Item.new(text: 'x', due: TODAY - 1, done_on: TODAY, created: TODAY)
    undated = Bramble::Item.new(text: 'x', created: TODAY)

    assert late.overdue?(TODAY)
    refute on_time.overdue?(TODAY)
    refute finished.overdue?(TODAY)
    refute undated.overdue?(TODAY)
  end

  def test_priority_rank_orders_low_to_high
    ranks = %i[low normal high].map { |p| Bramble::Item.new(text: 'x', priority: p).priority_rank }

    assert_equal ranks.sort, ranks
    assert_equal 3, ranks.uniq.size
  end
end
