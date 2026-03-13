# frozen_string_literal: true

module Components
  class PageCard < Base
    def default_attrs
      {
        class: "mx-1 break-words bg-white shadow-md shadow-red-50 rounded-lg"
      }
    end

    def view_template(&)
      div(**attrs, &)
    end
  end
end
