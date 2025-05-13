module Bramble
  PRIORITIES = %i[low normal high].freeze

  Item = Struct.new(:id, :kind, :text, :tags, :priority, :due, :created, :done_on, keyword_init: true) do
    def initialize(id: nil, kind: :todo, text:, tags: [], priority: :normal, due: nil, created: Date.today, done_on: nil)
      raise ArgumentError, "unknown kind #{kind.inspect}" unless %i[todo note].include?(kind)
      raise ArgumentError, "unknown priority #{priority.inspect}" unless PRIORITIES.include?(priority)

      super(id: id, kind: kind, text: text, tags: tags.uniq.sort, priority: priority, due: due, created: created, done_on: done_on)
    end

    def todo?
      kind == :todo
    end

    def note?
      kind == :note
    end

    def done?
      !done_on.nil?
    end

    def open?
      todo? && !done?
    end

    def overdue?(today)
      open? && !due.nil? && due < today
    end

    def priority_rank
      PRIORITIES.index(priority)
    end
  end
end
