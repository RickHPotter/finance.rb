# frozen_string_literal: true

module Components
  class ShellContainer < Base
    attr_reader :tag_name

    def initialize(tag: :div, **attrs)
      @tag_name = tag
      super(**attrs)
    end

    def view_template(&)
      public_send(tag_name, **attrs, &)
    end
  end
end
