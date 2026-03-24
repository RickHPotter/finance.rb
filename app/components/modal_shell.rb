# frozen_string_literal: true

module Components
  class ModalShell < Base
    include CacheHelper

    attr_reader :id, :title, :options

    def initialize(id:, title:, options: {})
      @id = id
      @title = title
      @options = options
    end

    def view_template
      div(
        id:,
        class: [
          "hidden fixed top-0 right-0 left-0 z-50 h-[calc(100%-1rem)] w-full items-center justify-center overflow-y-auto overflow-x-hidden bg-black/30 md:inset-0",
          options[:wrapper_class]
        ].compact.join(" "),
        tabindex: "-1",
        data: options[:wrapper_data]
      ) do
        div(class: [ "bg-white p-6 rounded-lg shadow-lg", options[:content_class] ].compact.join(" "), data: options[:content_data]) do
          div(class: "flex") do
            h1(class: "text-2xl mb-4 flex-1 text-start") { title }

            button(
              type: :button,
              class: "text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm w-8 h-8 ms-auto inline-flex justify-center items-center",
              data: options[:close_button_data] || { modal_hide: id }
            ) do
              cached_icon(:little_x)
              span(class: "sr-only") { "Close modal" }
            end
          end

          yield if block_given?
        end
      end
    end
  end
end
