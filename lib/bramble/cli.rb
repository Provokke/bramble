require 'optparse'

module Bramble
  class CLI
    USAGE = <<~TEXT.freeze
      usage: bramble [--file PATH] COMMAND [ARGS]

      commands:
        add TEXT...          add a todo        (words: #tag  @date  !priority)
        note TEXT...         add a note
        list [options]       show open todos and notes
        show ID              show everything about one item
        done ID...           mark todos done
        undo ID...           reopen todos
        edit ID TEXT...      change the text, tags, date or priority
        rm ID...             delete items
        search WORDS...      find items containing every word
        tags                 count items per tag
        stats                a short summary
        clear-done           delete every finished todo
        version              print the version

      list options:
        -a, --all            include finished todos
        -t, --tag TAG        only items with TAG
            --todos          only todos
            --notes          only notes
            --overdue        only overdue todos

      dates: today, tomorrow, mon..sun, +3d, +2w, YYYY-MM-DD
      priorities: !high  !normal  !low
    TEXT

    COMMANDS = {
      'add' => :add, 'note' => :note, 'list' => :list, 'ls' => :list, 'show' => :show, 'done' => :done,
      'undo' => :undo, 'edit' => :edit, 'rm' => :remove, 'search' => :search, 'tags' => :tags,
      'stats' => :stats, 'clear-done' => :clear_done, 'version' => :version, 'help' => :help
    }.freeze

    def self.default_path(env = ENV)
      env['BRAMBLE_FILE'] || File.join(env['HOME'] || Dir.pwd, '.bramble', 'items.txt')
    end

    def initialize(out: $stdout, err: $stderr, env: ENV, today: -> { Date.today })
      @out = out
      @err = err
      @env = env
      @today = today
    end

    def run(argv)
      args = argv.dup
      path = extract_file_option(args) || self.class.default_path(@env)
      name = args.shift
      return usage_error('no command given') if name.nil?

      command = COMMANDS[name] or return usage_error("unknown command: #{name}")
      @store = Store.new(path)
      send(:"cmd_#{command}", args)
      0
    rescue UsageError, NotFound, CorruptStore, OptionParser::ParseError => e
      @err.puts("bramble: #{e.message}")
      e.is_a?(NotFound) ? 1 : 2
    end

    private

    def today
      @today.call
    end

    def say(lines)
      Array(lines).each { |line| @out.puts(line) }
    end

    def usage_error(message)
      @err.puts("bramble: #{message}")
      @err.puts(USAGE)
      2
    end

    def extract_file_option(args)
      index = args.index('--file') || args.index('-f')
      return nil unless index

      value = args[index + 1] or raise UsageError, '--file needs a path'
      args.slice!(index, 2)
      value
    end

    def ids_from(args)
      raise UsageError, 'give at least one id' if args.empty?

      args.map do |arg|
        raise UsageError, "not an id: #{arg}" unless arg.match?(/\A\d+\z/)

        arg.to_i
      end
    end

    def require_text(args)
      parsed = QuickAdd.parse(args, today: today)
      raise UsageError, 'nothing to add' if parsed.text.empty?

      parsed
    end

    def cmd_add(args)
      parsed = require_text(args)
      item = @store.add(Item.new(
        kind: :todo, text: parsed.text, tags: parsed.tags, priority: parsed.priority || :normal,
        due: parsed.due, created: today
      ))
      say("added todo #{item.id}")
    end

    def cmd_note(args)
      parsed = require_text(args)
      item = @store.add(Item.new(kind: :note, text: parsed.text, tags: parsed.tags, created: today))
      say("added note #{item.id}")
    end

    def cmd_list(args)
      filters = { all: false, tag: nil, kind: nil, overdue: false }
      OptionParser.new do |o|
        o.on('-a', '--all') { filters[:all] = true }
        o.on('-t', '--tag TAG') { |tag| filters[:tag] = tag.delete_prefix('#').downcase }
        o.on('--todos') { filters[:kind] = :todo }
        o.on('--notes') { filters[:kind] = :note }
        o.on('--overdue') { filters[:overdue] = true }
      end.parse!(args)
      raise UsageError, "unexpected argument: #{args.first}" unless args.empty?

      items = @store.all.select do |item|
        next false if item.done? && !filters[:all]
        next false if filters[:kind] && item.kind != filters[:kind]
        next false if filters[:tag] && !item.tags.include?(filters[:tag])
        next false if filters[:overdue] && !item.overdue?(today)

        true
      end
      say(Formatter.list(items, today))
    end

    def cmd_show(args)
      ids = ids_from(args)
      raise UsageError, 'show takes one id' unless ids.size == 1

      say(Formatter.detail(@store.find(ids.first), today))
    end

    def cmd_done(args)
      change_todos(args, 'done') do |item|
        raise UsageError, "item #{item.id} is a note" if item.note?

        item.done_on ||= today
      end
    end

    def cmd_undo(args)
      change_todos(args, 'reopened') do |item|
        raise UsageError, "item #{item.id} is a note" if item.note?

        item.done_on = nil
      end
    end

    def change_todos(args, verb)
      ids_from(args).each do |id|
        @store.update(id) { |item| yield item }
        say("#{verb} #{id}")
      end
    end

    def cmd_edit(args)
      id = ids_from([args.shift.to_s]).first
      parsed = QuickAdd.parse(args, today: today)
      raise UsageError, 'nothing to change' if parsed.text.empty? && parsed.tags.empty? && parsed.due.nil? && parsed.priority.nil?

      @store.update(id) do |item|
        item.text = parsed.text unless parsed.text.empty?
        item.tags = (item.tags + parsed.tags).uniq.sort
        item.due = parsed.due if parsed.due
        item.priority = parsed.priority if parsed.priority
      end
      say("updated #{id}")
    end

    def cmd_remove(args)
      ids_from(args).each do |id|
        @store.delete(id)
        say("removed #{id}")
      end
    end

    def cmd_search(args)
      raise UsageError, 'search for what?' if args.empty?

      words = args.map(&:downcase)
      items = @store.all.select do |item|
        haystack = "#{item.text} #{item.tags.join(' ')}".downcase
        words.all? { |word| haystack.include?(word) }
      end
      say(Formatter.list(items, today))
    end

    def cmd_tags(_args)
      say(Formatter.tag_counts(@store.all))
    end

    def cmd_stats(_args)
      say(Formatter.stats(@store.all, today))
    end

    def cmd_clear_done(_args)
      removed = @store.delete_where { |item| item.todo? && item.done? }
      say("cleared #{removed.size} finished #{removed.size == 1 ? 'todo' : 'todos'}")
    end

    def cmd_version(_args)
      say("bramble #{VERSION}")
    end

    def cmd_help(_args)
      say(USAGE)
    end
  end
end
