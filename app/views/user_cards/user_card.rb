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
      class: "grid grid-cols-10 gap-2 border-b border-slate-200 #{cycle('bg-gray-100', 'bg-gray-200')} hover:bg-white",
      data: { id: user_card.id, datatable_target: :row }
    ) do
      div(class: "col-span-2 px-3 py-3 flex items-center mx-auto font-lekton font-semibold") do
        link_to user_card_path(user_card),
                id: "show_user_card_#{user_card.id}",
                class: "px-4 whitespace-nowrap hover:underline",
                data: { turbo_frame: "_top", turbo_prefetch: false } do
          brand_and_name
        end
      end

      div(class: "jump_to_card_transactions px-2 py-3 flex items-center justify-center mx-auto font-anonymous font-semibold whitespace-nowrap ml-auto") do
        if user_card.card_transactions_count.positive?
          link_to(
            user_card.card_transactions_count,
            card_transactions_path(user_card_id: user_card.id),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          )
        else
          span { user_card.card_transactions_count }
        end
      end

      div(class: "flex items-center justify-center px-2 py-3 text-lg whitespace-nowrap ml-auto") do
        span do
          from_cent_based_to_float(user_card.card_transactions_total, "R$")
        end
      end
      div(class: "flex items-center justify-center px-2 py-3 text-sm font-semibold text-slate-700") do
        status_badge
      end
      div(class: "flex items-center justify-center px-2 py-3 text-lg whitespace-nowrap ml-auto pr-2 border-r border-black") do
        span(class: "current_closing_date") { I18n.l(Date.current.change(day: user_card.due_date_day) - user_card.days_until_due_date, format: :shorter) }
      end
      div(class: "flex items-center justify-center px-2 py-3 text-lg whitespace-nowrap mr-auto") do
        span(class: "current_due_date") do
          I18n.l(Date.current.change(day: user_card.due_date_day), format: :shorter)
        end
      end
      div(class: "flex items-center justify-center px-2 py-3 font-lekton text-lg whitespace-nowrap ml-auto") do
        span do
          from_cent_based_to_float(user_card.min_spend, "R$")
        end
      end
      div(class: "flex items-center justify-center px-2 py-3 font-lekton text-lg whitespace-nowrap ml-auto") do
        span do
          from_cent_based_to_float(user_card.credit_limit, "R$")
        end
      end

      div(class: "flex items-center justify-center px-2 py-3") do
        div(class: "flex items-center justify-end gap-1") do
          link_to(edit_user_card_path(user_card), id: "edit_user_card_#{user_card.id}",
                                                  class: action_button_class,
                                                  title: action_message(:edit),
                                                  aria: { label: action_message(:edit) },
                                                  data: { turbo_frame: "_top", turbo_prefetch: false }) { cached_icon(:pencil) }

          LinkWithConfirmation(
            id: user_card.id,
            icon: :destroy,
            link_params: {
              href: user_card_path(user_card),
              size: :xs,
              id: "delete_user_card_#{user_card.id}",
              class: destructive_action_button_class,
              data: { turbo_method: :delete }
            }
          )
        end
      end
    end
  end

  def mobile_row
    brand_name = user_card.card.card_name
    brand_and_name = brand_name == user_card.user_card_name ? brand_name : "#{brand_name} - #{user_card.user_card_name}"

    div(class: "rounded-lg shadow-sm overflow-hidden my-3 bg-slate-100", data: { id: user_card.id, datatable_target: :row }) do
      div(class: "p-4 bg-linear-to-r from-blue-500 to-blue-700") do
        div(class: "flex items-center justify-between") do
          div(class: "flex items-center space-x-3") do
            cached_icon :credit_card
            link_to(brand_and_name, user_card_path(user_card), id: "show_user_card_#{user_card.id}",
                                                               class: "text-lg font-semibold text-black underline underline-offset-[3px]",
                                                               data: { turbo_frame: "_top", turbo_prefetch: false })
          end
          status_badge
        end

        div(class: "mt-2 flex justify-end") do
          link_to(card_transactions_path(user_card_id: user_card.id), data: { turbo_frame: "_top", turbo_prefetch: false }) { cached_icon(:jump_to) }
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

  def action_button_class
    "inline-flex size-6 items-center justify-center rounded-sm border border-sky-200 bg-sky-50 text-sky-700 " \
      "shadow-sm transition hover:border-sky-600 hover:bg-sky-600 hover:text-white [&_svg]:size-4"
  end

  def destructive_action_button_class
    "inline-flex size-6 items-center justify-center rounded-sm border border-red-200 bg-white text-red-700 " \
      "shadow-sm transition hover:border-red-600 hover:bg-red-600 hover:text-white [&_svg]:size-4 [&_svg]:!text-current"
  end

  def status_badge
    colour = user_card.active? ? "bg-emerald-100 text-emerald-800" : "bg-slate-200 text-slate-700"

    span(class: "rounded-full px-2.5 py-1 text-xs font-semibold uppercase tracking-wide #{colour}") do
      model_attribute(UserCard, "statuses.#{user_card.active? ? :active : :inactive}")
    end
  end
end
