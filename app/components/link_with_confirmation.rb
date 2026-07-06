# frozen_string_literal: true

module Components
  class LinkWithConfirmation < Base
    include CacheHelper
    include ComponentsHelper

    attr_reader :id, :link_params, :icon, :text

    def initialize(id:, link_params:, icon: nil, text: "")
      @id = id
      @link_params = link_params
      @icon = icon
      @text = text
    end

    def view_template(&)
      modal_id = "linkWithConfirmDialog_#{id}"
      trigger_id = link_params[:id] || "linkWithConfirmTrigger_#{id}"
      destructive_method = link_params.dig(:data, :turbo_method)
      confirm_data = { controller: :confirm, confirm_link_id_value: trigger_id }

      if destructive_method.present?
        confirm_data[:confirm_href_value] = link_params[:href]
        confirm_data[:confirm_method_value] = destructive_method
        confirm_data[:confirm_turbo_frame_value] = link_params.dig(:data, :turbo_frame) if link_params.dig(:data, :turbo_frame).present?
        confirm_data[:confirm_turbo_stream_value] = link_params.dig(:data, :turbo_stream) if link_params.dig(:data, :turbo_stream).present?
        confirm_data[:confirm_turbo_action_value] = link_params.dig(:data, :turbo_action) if link_params.dig(:data, :turbo_action).present?
      end

      link_params[:id] = trigger_id
      link_params[:data] ||= {}
      link_params[:data][:modal_target] = modal_id
      link_params[:data][:modal_toggle] = modal_id

      div(
        id: modal_id,
        class: "hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)]",
        tabindex: "-1",
        data: confirm_data
      ) do
        div(class: "bg-white p-6 rounded-lg shadow-lg dark:border dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 dark:shadow-black/40") do
          div(class: "flex") do
            h1(class: "text-2xl mb-4 flex-1 text-start text-gray-900 dark:text-slate-100") do
              I18n.t("confirmation.sure")
            end

            button(
              type: :button,
              class: modal_close_button_class,
              data: { modal_hide: modal_id }
            ) do
              cached_icon(:little_x)

              span(class: "sr-only") do
                "Close modal"
              end
            end
          end

          div(class: "flex justify-center gap-4 text-md text-white") do
            Button(type: :button, variant: :destructive, class: "font-bold py-2 px-4 rounded", data: { action: "confirm#proceed", modal_hide: modal_id }) do
              I18n.t("confirmation.confirm")
            end

            Button(
              type: :button,
              variant: :outline,
              class: "font-bold py-2 px-4 rounded text-gray-900 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800",
              data: { modal_hide: modal_id }
            ) do
              I18n.t("confirmation.cancel")
            end
          end
        end
      end

      if destructive_method.present?
        Button(
          type: :button,
          variant: link_params[:variant] || :link,
          size: link_params[:size] || :md,
          id: trigger_id,
          class: link_params[:class],
          data: link_params[:data]
        ) do
          if icon
            cached_icon icon
          else
            text
          end
        end
      else
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
end
