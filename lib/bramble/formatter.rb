module Bramble
  module Formatter
    PRIORITY_MARKS = { high: '!', normal: ' ', low: '.' }.freeze
    DATE_WIDTH = 10

    module_function

    def sort(items, today)
      items.sort_by do |item|
        [
          item.note? ? 1 : 0,
          item.done? ? 1 : 0,
          item.overdue?(today) ? 0 : 1,
          item.due ? item.due.jd : Float::INFINITY,
          -item.priority_rank,
          item.id
        ]
      end
    end

    def list(items, today)
      return ['nothing here'] if items.empty?

      width = items.map { |item| item.id.to_s.size }.max
      sort(items, today).map { |item| row(item, today, width) }
    end

    def row(item, today, id_width)
      parts = [
        item.id.to_s.rjust(id_width),
        mark(item),
        PRIORITY_MARKS.fetch(item.priority),
        (item.due ? item.due.iso8601 : '').ljust(DATE_WIDTH),
        item.text
      ]
      parts << item.tags.map { |tag| "##{tag}" }.join(' ') unless item.tags.empty?
      parts << '(overdue)' if item.overdue?(today)
      parts.join(' ').rstrip
    end

    def mark(item)
      return '(n)' if item.note?

      item.done? ? '[x]' : '[ ]'
    end

    def detail(item, today)
      lines = [
        "id:       #{item.id}",
        "kind:     #{item.kind}",
        "text:     #{item.text}",
        "priority: #{item.priority}",
        "created:  #{item.created.iso8601}"
      ]
      lines << "due:      #{item.due.iso8601}#{item.overdue?(today) ? ' (overdue)' : ''}" if item.due
      lines << "done:     #{item.done_on.iso8601}" if item.done?
      lines << "tags:     #{item.tags.join(', ')}" unless item.tags.empty?
      lines
    end

    def tag_counts(items)
      counts = Hash.new(0)
      items.each { |item| item.tags.each { |tag| counts[tag] += 1 } }
      return ['no tags'] if counts.empty?

      width = counts.keys.map(&:size).max
      counts.sort_by { |tag, count| [-count, tag] }.map { |tag, count| "#{tag.ljust(width)}  #{count}" }
    end

    def stats(items, today)
      todos = items.select(&:todo?)
      [
        "open:    #{todos.count(&:open?)}",
        "done:    #{todos.count(&:done?)}",
        "overdue: #{todos.count { |item| item.overdue?(today) }}",
        "notes:   #{items.count(&:note?)}"
      ]
    end
  end
end
