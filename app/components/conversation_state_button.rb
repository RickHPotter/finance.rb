# frozen_string_literal: true

module Components
  class ConversationStateButton < Base
    ACTION_CLASSES = {
      archive: "border-slate-300 bg-white text-slate-700 hover:border-slate-400 hover:bg-slate-100 focus-visible:ring-slate-400 " \
               "dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:border-slate-500 dark:hover:bg-slate-800",
      unarchive: "border-sky-300 bg-sky-50 text-sky-800 hover:border-sky-400 hover:bg-sky-100 focus-visible:ring-sky-400 " \
                 "dark:border-sky-700 dark:bg-sky-950/50 dark:text-sky-200 dark:hover:border-sky-600 dark:hover:bg-sky-900/60",
      mute: "border-violet-300 bg-violet-50 text-violet-800 hover:border-violet-400 hover:bg-violet-100 focus-visible:ring-violet-400 " \
            "dark:border-violet-700 dark:bg-violet-950/50 dark:text-violet-200 dark:hover:border-violet-600 dark:hover:bg-violet-900/60",
      unmute: "border-violet-500 bg-violet-600 text-white hover:border-violet-600 hover:bg-violet-700 focus-visible:ring-violet-500 " \
              "dark:border-violet-400 dark:bg-violet-500 dark:text-slate-950 dark:hover:bg-violet-400"
    }.freeze
    ACTIONS = ACTION_CLASSES.keys.freeze

    attr_reader :action, :href, :label

    def initialize(action:, href:, label:, **attrs)
      @action = action.to_sym
      @href = href
      @label = label
      raise ArgumentError, "invalid conversation state action" unless action.in?(ACTIONS)

      super(**attrs)
      self.attrs[:data] = (self.attrs[:data] || {}).merge(conversation_action: action)
      self.attrs[:aria] = (self.attrs[:aria] || {}).merge(label:)
    end

    def view_template
      a(href:, **attrs) { label }
    end

    private

    def default_attrs
      {
        class: "inline-flex min-h-8 items-center justify-center rounded-lg border px-3 py-1.5 text-xs font-semibold no-underline shadow-sm " \
               "transition-colors hover:no-underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 #{action_classes}"
      }
    end

    def action_classes
      ACTION_CLASSES.fetch(action)
    end
  end
end
