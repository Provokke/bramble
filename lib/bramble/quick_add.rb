module Bramble
  class QuickAdd
    WEEKDAYS = %w[sunday monday tuesday wednesday thursday friday saturday].freeze
    PRIORITY_WORDS = {
      'high' => :high, 'h' => :high, 'low' => :low, 'l' => :low, 'normal' => :normal, 'n' => :normal
    }.freeze

    Result = Struct.new(:text, :tags, :due, :priority, keyword_init: true)

    def self.parse(input, today: Date.today)
      new(today).parse(input)
    end

    def initialize(today)
      @today = today
    end

    def parse(input)
      words = []
      tags = []
      due = nil
      priority = nil

      Array(input).join(' ').split(/\s+/).reject(&:empty?).each do |token|
        case token
        when /\A#(\w[\w-]*)\z/
          tags << Regexp.last_match(1).downcase
        when /\A@(\S+)\z/
          due = parse_date(Regexp.last_match(1))
        when /\A!(\w+)\z/
          priority = parse_priority(Regexp.last_match(1))
        else
          words << token
        end
      end

      Result.new(text: words.join(' '), tags: tags.uniq, due: due, priority: priority)
    end

    def parse_date(word)
      word = word.downcase
      case word
      when 'today' then @today
      when 'tomorrow' then @today + 1
      when /\A\+(\d+)([dw])\z/
        count = Regexp.last_match(1).to_i
        count *= 7 if Regexp.last_match(2) == 'w'
        @today + count
      when /\A(\d{4})-(\d{2})-(\d{2})\z/
        year, month, day = Regexp.last_match.captures.map(&:to_i)
        raise UsageError, "not a real date: #{word}" unless Date.valid_date?(year, month, day)

        Date.new(year, month, day)
      else
        weekday_date(word) || raise(UsageError, "unknown date: @#{word}")
      end
    end

    private

    def weekday_date(word)
      index = WEEKDAYS.index { |name| name == word || name[0, 3] == word }
      return nil unless index

      ahead = (index - @today.wday) % 7
      @today + (ahead.zero? ? 7 : ahead)
    end

    def parse_priority(word)
      PRIORITY_WORDS.fetch(word.downcase) { raise UsageError, "unknown priority: !#{word}" }
    end
  end
end
