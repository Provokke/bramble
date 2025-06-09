require 'test_helper'

class QuickAddTest < Minitest::Test
  def parse(*words)
    Bramble::QuickAdd.parse(words, today: TODAY)
  end

  def test_plain_text_is_kept
    result = parse('buy', 'milk')

    assert_equal 'buy milk', result.text
    assert_equal [], result.tags
    assert_nil result.due
    assert_nil result.priority
  end

  def test_whitespace_is_collapsed
    assert_equal 'a b c', parse("  a   b\tc ").text
  end

  def test_tags_are_extracted_lowercased_and_deduplicated
    result = parse('call mum #Family #home #family')

    assert_equal 'call mum', result.text
    assert_equal %w[family home], result.tags
  end

  def test_tags_may_contain_hyphens
    assert_equal ['side-project'], parse('x #side-project').tags
  end

  def test_priority_words
    assert_equal :high, parse('x !high').priority
    assert_equal :high, parse('x !h').priority
    assert_equal :low, parse('x !LOW').priority
    assert_equal :normal, parse('x !normal').priority
  end

  def test_unknown_priority_is_an_error
    assert_raises(Bramble::UsageError) { parse('x !urgent') }
  end

  def test_relative_dates
    assert_equal TODAY, parse('x @today').due
    assert_equal TODAY + 1, parse('x @tomorrow').due
    assert_equal TODAY + 3, parse('x @+3d').due
    assert_equal TODAY + 14, parse('x @+2w').due
  end

  def test_iso_dates
    assert_equal Date.new(2027, 1, 5), parse('x @2027-01-05').due
  end

  def test_impossible_iso_date_is_an_error
    error = assert_raises(Bramble::UsageError) { parse('x @2026-02-30') }

    assert_match(/not a real date/, error.message)
  end

  def test_weekdays_are_the_next_occurrence
    assert_equal Date.new(2026, 11, 20), parse('x @friday').due
    assert_equal Date.new(2026, 11, 23), parse('x @mon').due
    assert_equal Date.new(2026, 11, 22), parse('x @sunday').due
  end

  def test_weekday_matching_today_means_next_week
    assert_equal TODAY + 7, parse('x @thursday').due
  end

  def test_unknown_date_is_an_error
    error = assert_raises(Bramble::UsageError) { parse('x @someday') }

    assert_match(/unknown date/, error.message)
  end

  def test_everything_together
    result = parse('ship', 'release', '#work', '@fri', '!high', 'notes')

    assert_equal 'ship release notes', result.text
    assert_equal ['work'], result.tags
    assert_equal Date.new(2026, 11, 20), result.due
    assert_equal :high, result.priority
  end

  def test_email_addresses_stay_in_the_text
    assert_equal 'mail bob@example.com', parse('mail bob@example.com').text
  end

  def test_lone_symbols_stay_in_the_text
    assert_equal 'a # b ! c', parse('a # b ! c').text
  end
end
