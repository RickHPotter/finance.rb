# frozen_string_literal: true

class Views::UserCards::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::TextFieldTag

  include CacheHelper
  include TranslateHelper
  include ComponentsHelper

  attr_reader :user_cards, :mobile

  def initialize(user_cards:, mobile: false)
    @user_cards = user_cards
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "flex min-h-[calc(100svh-18rem)] flex-col rounded-lg bg-white shadow-md") do
        mobile ? mobile_index : desktop_index
      end
    end
  end

  private

  def include_inactive?
    params[:include_inactive] == "false"
  end

  def desktop_index
    div(class: "flex justify-between mb-6 bg-white p-4 shadow-md rounded-lg") do
      link_to(
        action_model(:new, UserCard),
        new_user_card_path,
        class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
        data: { turbo_frame: "_top" }
      )

      link_to(
        include_inactive? ? action_message(:show_inactive) : action_message(:hide_inactive),
        user_cards_path(include_inactive: include_inactive?),
        class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
        data: { turbo_frame: "_top" }
      )
    end

    div(class: "min-w-full") do
      turbo_frame_tag :user_cards do
        div(data: { controller: "datatable" }) do
          text_field_tag(
            :search,
            nil,
            type: :text,
            placeholder: "#{action_message(:search)}...",
            class: "w-full border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent",
            data: { action: "input->datatable#filter" }
          )

          div(class: "my-4", data: { datatable_target: "table" }) do
            div(class: "rounded-lg border-1 border-slate-300 shadow-sm overflow-hidden") do
              div(class: "bg-slate-300 grid grid-cols-9 py-1 border-b border-slate-400 rounded-t-lg font-semibold text-black font-graduate") do
                div(class: "col-span-2")
                div(class: "text-center col-span-2 text-slate-600") { pluralise_model(CardTransaction, 2) }
                div(class: "col-span-5")
              end

              div(class: "bg-slate-300 grid grid-cols-9 py-1 gap-1 border-b border-slate-400 font-semibold text-black font-graduate") do
                div(class: "col-span-2 text-center") { model_attribute(UserCard, :user_card_name) }
                div(class: "text-center") { model_attribute(UserCard, :count) }
                div(class: "text-center") { model_attribute(UserCard, :spent) }
                div(class: "text-end text-lime-800 pr-2") { model_attribute(UserCard, :closing_date) }
                div(class: "text-start text-red-800") { model_attribute(UserCard, :due_date) }
                div(class: "text-end") { model_attribute(UserCard, :min_spend) }
                div(class: "text-end") { model_attribute(UserCard, :credit_limit) }
                div(class: "text-center") { I18n.t(:datatable_actions) }
              end

              if user_cards.present?
                user_cards.each do |record|
                  render Views::UserCards::UserCard.new(user_card: record, mobile: false)
                end
              else
                div(class: "border-b border-slate-200 py-2 my-2 text-lg bg-white") { I18n.t(:rows_not_found) }
              end
            end
          end
        end
      end
    end
  end

  def mobile_index
    div(class: "w-full") do
      div(class: "min-w-full") do
        turbo_frame_tag :user_cards do
          div(data: { controller: "datatable" }) do
            div(class: "p-3 mb-6 bg-white rounded-lg shadow-sm grid grid-cols-1 gap-2") do
              link_to(
                include_inactive? ? action_message(:show_inactive) : action_message(:hide_inactive),
                user_cards_path(include_inactive: include_inactive?),
                class: "p-1 rounded-sm border border-slate-700 bg-sky-500 hover:bg-blue-400 transition-colors text-white shadow-lg font-thin",
                data: { turbo_frame: "_top" }
              )

              text_field_tag(
                :search,
                nil,
                type: :text,
                placeholder: "#{action_message(:search)}...",
                class: "w-full border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent",
                data: { action: "input->datatable#filter" }
              )
            end

            div(class: "mb-8", data: { datatable_target: "table" }) do
              if user_cards.present?
                user_cards.each do |record|
                  render Views::UserCards::UserCard.new(user_card: record, mobile: true)
                end
              else
                div(class: "border-b border-slate-200 py-2 my-2 text-lg bg-white") { I18n.t(:rows_not_found) }
              end
            end
          end

          link_to(
            new_user_card_path,
            style: "margin: 30px",
            class: "fixed bottom-0 right-0 bg-blue-600 text-white rounded-full shadow-lg flex items-center justify-center z-50 active:scale-95 transition-transform",
            data: { turbo_frame: "_top" }
          ) { cached_icon(:bigger_plus) }
        end
      end
    end
  end
end
