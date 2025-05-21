require 'fileutils'

module Bramble
  class Store
    KINDS = { 't' => :todo, 'n' => :note }.freeze
    FIELDS = 8

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def all
      with_lock(File::LOCK_SH) { read_items }
    end

    def find(id)
      all.find { |item| item.id == id } || raise(NotFound, id)
    end

    def add(item)
      transaction do |items|
        item.id = (items.map(&:id).max || 0) + 1
        items << item
        item
      end
    end

    def update(id)
      transaction do |items|
        item = items.find { |candidate| candidate.id == id } or raise NotFound, id
        yield item
        item
      end
    end

    def delete(id)
      transaction do |items|
        removed = items.reject! { |item| item.id == id }
        raise NotFound, id unless removed

        id
      end
    end

    def delete_where
      transaction do |items|
        removed = items.select { |item| yield item }
        items.reject! { |item| removed.include?(item) }
        removed
      end
    end

    def transaction
      with_lock(File::LOCK_EX) do
        items = read_items
        result = yield items
        write_items(items)
        result
      end
    end

    def self.dump_line(item)
      [
        item.id,
        KINDS.key(item.kind),
        item.priority,
        item.created.iso8601,
        item.due ? item.due.iso8601 : '-',
        item.done_on ? item.done_on.iso8601 : '-',
        item.tags.empty? ? '-' : item.tags.join(','),
        escape(item.text)
      ].join("\t")
    end

    def self.parse_line(line)
      fields = line.split("\t", FIELDS)
      raise ArgumentError, "expected #{FIELDS} fields, found #{fields.size}" unless fields.size == FIELDS

      id, kind, priority, created, due, done_on, tags, text = fields
      raise ArgumentError, "bad id #{id.inspect}" unless id.match?(/\A\d+\z/)
      raise ArgumentError, "bad kind #{kind.inspect}" unless KINDS.key?(kind)
      raise ArgumentError, "bad priority #{priority.inspect}" unless PRIORITIES.include?(priority.to_sym)

      Item.new(
        id: id.to_i, kind: KINDS[kind], text: unescape(text), priority: priority.to_sym,
        tags: tags == '-' ? [] : tags.split(','), created: Date.iso8601(created),
        due: due == '-' ? nil : Date.iso8601(due), done_on: done_on == '-' ? nil : Date.iso8601(done_on)
      )
    rescue Date::Error
      raise ArgumentError, 'bad date'
    end

    def self.escape(text)
      text.gsub(/[\\\t\n\r]/, "\\" => '\\\\', "\t" => '\\t', "\n" => '\\n', "\r" => '\\r')
    end

    def self.unescape(text)
      text.gsub(/\\(.)/m) do
        case Regexp.last_match(1)
        when 't' then "\t"
        when 'n' then "\n"
        when 'r' then "\r"
        else Regexp.last_match(1)
        end
      end
    end

    private

    def read_items
      return [] unless File.exist?(path)

      items = []
      File.foreach(path, chomp: true).with_index(1) do |line, number|
        next if line.strip.empty? || line.start_with?('#')

        begin
          items << self.class.parse_line(line)
        rescue ArgumentError => e
          raise CorruptStore.new(path, number, e.message)
        end
      end
      items
    end

    def write_items(items)
      FileUtils.mkdir_p(File.dirname(path))
      temp = "#{path}.tmp#{Process.pid}"
      File.write(temp, items.sort_by(&:id).map { |item| "#{self.class.dump_line(item)}\n" }.join)
      File.rename(temp, path)
    ensure
      File.delete(temp) if temp && File.exist?(temp)
    end

    def with_lock(mode)
      FileUtils.mkdir_p(File.dirname(path))
      File.open("#{path}.lock", File::RDWR | File::CREAT, 0o644) do |lock|
        lock.flock(mode)
        yield
      end
    end
  end
end
