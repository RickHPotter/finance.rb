# frozen_string_literal: true

class Views::UserCards::UserCard < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::Cycle

  include CacheHelper
  include TranslateHelper

  attr_reader :user_card, :mobile

  def initialize(user_card:, mobile: false)
    @user_card = user_card
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag dom_id(user_card) do
      mobile ? mobile_row : desktop_row
    end
  end

  private

  def desktop_row
    brand_name = user_card.card.card_name
    brand_and_name = brand_name == user_card.user_card_name ? brand_name : "#{brand_name} - #{user_card.user_card_name}"

    div(
      class: "grid grid-cols-9 gap-2 border-b border-slate-200 #{cycle('bg-gray-100', 'bg-gray-200')} hover:bg-white",
      data: { id: user_card.id, datatable_target: :row }
    ) do
      div(class: "col-span-2 px-1 flex items-center mx-auto font-lekton font-semibold") { span(class: "px-4 whitespace-nowrap") { brand_and_name } }

      div(class: "jump_to_card_transactions px-1 flex items-center justify-center mx-auto font-anonymous font-semibold whitespace-nowrap ml-auto") do
        if user_card.card_transactions_count.positive?
          link_to(
            user_card.card_transactions_count,
            card_transactions_path(user_card_id: user_card.id),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: :_top, turbo_prefetch: false }
          )
        else
          span { user_card.card_transactions_count }
        end
      end

      div(class: "flex items-center justify-center text-lg whitespace-nowrap ml-auto") { span { from_cent_based_to_float(user_card.card_transactions_total, "R$") } }
      div(class: "flex items-center justify-center text-lg whitespace-nowrap ml-auto pr-2 border-r border-black") do
        span(class: "current_closing_date") { I18n.l(Date.current.change(day: user_card.due_date_day) - user_card.days_until_due_date, format: :shorter) }
      end
      div(class: "flex items-center justify-center text-lg whitespace-nowrap mr-auto") do
        span(class: "current_due_date") do
          I18n.l(Date.current.change(day: user_card.due_date_day), format: :shorter)
        end
      end
      div(class: "flex items-center justify-center font-lekton text-lg whitespace-nowrap ml-auto") { span { from_cent_based_to_float(user_card.min_spend, "R$") } }
      div(class: "flex items-center justify-center font-lekton text-lg whitespace-nowrap ml-auto") { span { from_cent_based_to_float(user_card.credit_limit, "R$") } }

      div(class: "flex items-center justify-center") do
        div(class: "flex items-center justify-center px-2 my-1 rounded-md") do
          link_to(edit_user_card_path(user_card), id: "edit_user_card_#{user_card.id}",
                                                  class: "text-blue-600 hover:text-blue-800 mx-2 bg-sky-200 rounded-4xl",
                                                  data: { turbo_frame: :_top }) { cached_icon(:pencil) }

          link_to(user_card_path(user_card), id: "delete_user_card_#{user_card.id}",
                                             class: "text-red-600 hover:text-red-800 mx-2 bg-rose-200 rounded-4xl",
                                             data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }) { cached_icon(:destroy) }
        end
      end
    end
  end

  def mobile_row
    brand_name = user_card.card.card_name
    brand_and_name = brand_name == user_card.user_card_name ? brand_name : "#{brand_name} - #{user_card.user_card_name}"

    div(class: "rounded-lg shadow-sm overflow-hidden my-3 bg-slate-100", data: { id: user_card.id, datatable_target: :row }) do
      div(class: "p-4 bg-gradient-to-r from-blue-500 to-blue-700") do
        div(class: "flex items-center justify-between") do
          div(class: "flex items-center space-x-3") do
            cached_icon :credit_card
            link_to(brand_and_name, edit_user_card_path(user_card), id: "edit_user_card_#{user_card.id}",
                                                                    class: "text-lg font-semibold text-black underline underline-offset-[3px]",
                                                                    data: { turbo_frame: :_top })
          end

          link_to(card_transactions_path(user_card_id: user_card.id), data: { turbo_frame: :_top, turbo_prefetch: false }) { cached_icon(:jump_to) }
        end
      end

      div(class: "p-4") do
        div(class: "grid grid-cols-2 gap-4 my-2") do
          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :number
              span(class: "text-sm font-medium text-slate-500") { pluralise_model(CardTransaction, 2) }
            end

            div(class: "flex items-center") { span(class: "text-sm font-semibold text-slate-800") { user_card.card_transactions_count } }
          end

          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :money
              span(class: "text-sm font-medium text-slate-500") { model_attribute(CardTransaction, :total_amount) }
            end

            div(class: "flex items-center") do
              span(class: "text-sm font-semibold text-slate-800 mr-auto") do
                from_cent_based_to_float(user_card.card_transactions_total, "R$")
              end
            end
          end
        end

        div(class: "grid grid-cols-2 gap-4 my-2") do
          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :calendar
              span(class: "text-sm font-medium text-slate-500") { model_attribute(UserCard, :current_closing_date) }
            end

            div(class: "flex items-center") { span { I18n.l(Date.current.change(day: user_card.due_date_day) - user_card.days_until_due_date, format: :short) } }
          end

          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :calendar
              span(class: "text-sm font-medium text-slate-500") { model_attribute(UserCard, :current_due_date) }
            end

            div(class: "flex items-center") { span { I18n.l(Date.current.change(day: user_card.due_date_day), format: :short) } }
          end
        end
      end
    end
  end
end
