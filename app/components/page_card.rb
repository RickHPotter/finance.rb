# frozen_string_literal: true

module Components
  class PageCard < Base
    def default_attrs
      {
        class: "mx-1 flex min-h-0 flex-1 flex-col wrap-break-words rounded-lg border border-transparent bg-white shadow-md shadow-red-50 " \
               "dark:border-slate-800 dark:bg-black dark:shadow-slate-950"
      }
    end

    def view_template(&)
      div(**attrs, &)
    end
  end
end
