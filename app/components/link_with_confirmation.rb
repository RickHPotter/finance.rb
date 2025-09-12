# frozen_string_literal: true

module Components
  class LinkWithConfirmation < Base
    include CacheHelper

    attr_reader :id, :link_params, :icon, :text

    def initialize(id:, link_params:, icon: nil, text: "")
      @id = id
      @link_params = link_params
      @icon = icon
      @text = text
    end

    def view_template(&)
      modal_id = "linkWithConfirmDialog_#{id}"

      link_params[:data] ||= {}
      link_params[:data][:modal_target] = modal_id
      link_params[:data][:modal_toggle] = modal_id

      div(
        id: modal_id,
        class: "hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)]",
        tabindex: "-1",
        data: { controller: :confirm, confirm_target: :dialog }
      ) do
        div(class: "bg-white p-6 rounded-lg shadow-lg") do
          div(class: "flex") do
            h1(class: "text-2xl mb-4 flex-1 text-start") do
              I18n.t("confirmation.sure")
            end

            button(
              type: :button,
              class: "text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm w-8 h-8 ms-auto inline-flex justify-center items-center",
              data: { modal_hide: modal_id }
            ) do
              cached_icon(:little_x)

              span(class: "sr-only") do
                "Close modal"
              end
            end
          end

          div(class: "flex justify-center gap-4 text-md") do
            Button(type: :button, variant: :destructive, class: "font-bold py-2 px-4 rounded", data: { action: "confirm#proceed", modal_hide: modal_id }) do
              I18n.t("confirmation.confirm")
            end

            Button(type: :button, variant: :outline, class: "font-bold py-2 px-4 rounded", data: { modal_hide: modal_id }) do
              I18n.t("confirmation.cancel")
            end
          end
        end
      end

      Link(**link_params) do
        if icon
          cached_icon icon
        else
          text
        end
      end
    end
  end
end
