# frozen_string_literal: true

module Components
  class FloatingNavButton < Base
    attr_reader :side, :title, :target, :action

    def initialize(side:, title:, target:, action:)
      @side = side
      @title = title
      @target = target
      @action = action
      super
    end

    def view_template(&)
      button(
        type: :button,
        class: "#{side_class}
                fixed top-1/2 -translate-y-1/2 z-40 rounded-full border border-slate-300 bg-white/90 p-3 text-black shadow-lg transition-all hover:bg-slate-100",
        title:,
        data: { history_nav_target: target, action: }, &
      )
    end

    private

    def side_class
      side == :left ? "left-4" : "right-4"
    end
  end
end
