# frozen_string_literal: true

module Components
  class ModalShell < Base
    include CacheHelper

    attr_reader :id, :title, :close_button_data, :wrapper_data, :content_data

    def initialize(id:, title:, close_button_data: nil, wrapper_data: nil, content_data: nil)
      @id = id
      @title = title
      @close_button_data = close_button_data
      @wrapper_data = wrapper_data
      @content_data = content_data
    end

    def view_template
      div(
        id:,
        class: "hidden fixed top-0 right-0 left-0 z-50 h-[calc(100%-1rem)] w-full items-center justify-center
                overflow-y-auto overflow-x-hidden bg-black/30 md:inset-0".squish,
        tabindex: "-1",
        data: wrapper_data
      ) do
        div(class: "bg-white p-6 rounded-lg shadow-lg", data: content_data) do
          div(class: "flex") do
            h1(class: "text-2xl mb-4 flex-1 text-start") { title }

            button(
              type: :button,
              class: "text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm w-8 h-8 ms-auto inline-flex justify-center items-center",
              data: close_button_data || { modal_hide: id }
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
