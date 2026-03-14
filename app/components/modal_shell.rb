# frozen_string_literal: true

module Components
  class ModalShell < Base
    include CacheHelper

    attr_reader :id, :title

    def initialize(id:, title:)
      @id = id
      @title = title
    end

    def view_template
      div(
        id:,
        class: "hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)]",
        tabindex: "-1"
      ) do
        div(class: "bg-white p-6 rounded-lg shadow-lg") do
          div(class: "flex") do
            h1(class: "text-2xl mb-4 flex-1 text-start") { title }

            button(
              type: :button,
              class: "text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm w-8 h-8 ms-auto inline-flex justify-center items-center",
              data: { modal_hide: id }
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
