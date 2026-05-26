# frozen_string_literal: true

class Views::Categories::Category < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::Cycle

  include CacheHelper
  include ColoursHelper
  include TranslateHelper

  attr_reader :category, :mobile

  def initialize(category:, mobile: false)
    @category = category
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag dom_id(category) do
      mobile ? mobile_row : desktop_row
    end
  end

  private

  def desktop_row
    bg = solid_or_gradient_style(category)
    text = auto_text_color(category.hex_colour)

    div(
      class: "grid grid-cols-8 border-b border-slate-200 #{cycle('bg-gray-100', 'bg-gray-200')} hover:bg-white",
      data: { id: category.id, datatable_target: :row }
    ) do
      div(class: "col-span-2 px-3 py-3 flex items-center mx-auto font-lekton font-semibold") do
        link_to category_path(category),
                id: "show_category_#{category.id}",
                class: "px-4 whitespace-nowrap border-0 rounded-sm shadow-md hover:opacity-85",
                style: "background-clip: padding-box; #{bg}; #{text}",
                data: { turbo_frame: "_top", turbo_prefetch: false } do
          category.name
        end
      end

      div(class: "flex items-center justify-center px-2 py-3 text-sm font-semibold text-slate-700") do
        status_badge
      end

      div(class: "jump_to_card_transactions px-2 py-3 flex items-center justify-center font-anonymous font-semibold whitespace-nowrap text-md") do
        if category.card_transactions_count.positive?
          link_to(
            category.card_transactions_count,
            search_card_transactions_path(card_transaction: { category_id: category.id }, all_month_years: true),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          )
        else
          span { category.card_transactions_count }
        end
      end

      div(class: "flex items-center justify-center px-2 py-3 font-lekton font-normal text-lg whitespace-nowrap") do
        span do
          from_cent_based_to_float(category.card_transactions_total, "R$")
        end
      end

      div(class: "jump_to_cash_transactions px-2 py-3 flex items-center justify-center font-anonymous font-semibold whitespace-nowrap text-md") do
        if category.cash_transactions_count.positive?
          link_to(
            category.cash_transactions_count,
            cash_transactions_path(cash_transaction: { category_id: category.id }, all_month_years: true),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          )
        else
          span { category.cash_transactions_count }
        end
      end

      div(class: "flex items-center justify-center px-2 py-3 font-lekton font-normal text-lg whitespace-nowrap") do
        span do
          from_cent_based_to_float(category.cash_transactions_total, "R$")
        end
      end

      div(class: "flex items-center justify-center px-2 py-3") do
        div(class: "flex items-center justify-end gap-1") do
          link_to(edit_category_path(category), id: "edit_category_#{category.id}",
                                                class: action_button_class,
                                                title: action_message(:edit),
                                                aria: { label: action_message(:edit) },
                                                data: { turbo_frame: "_top", turbo_prefetch: false }) { cached_icon(:pencil) }

          if category.built_in == false
            LinkWithConfirmation(
              id: category.id,
              icon: :destroy,
              link_params: {
                href: category_path(category),
                size: :xs,
                id: "delete_category_#{category.id}",
                class: destructive_action_button_class,
                data: { turbo_method: :delete }
              }
            )
          end
        end
      end
    end
  end

  def mobile_row
    bg = solid_or_gradient_style(category)
    text = auto_text_color(category.hex_colour)

    div(class: "mx-2 rounded-lg shadow-sm overflow-hidden my-3", data: { id: category.id, datatable_target: :row }) do
      div(class: "p-4 whitespace-nowrap border-0 rounded-sm shadow-md", style: "background-clip: padding-box; #{bg}; #{text}") do
        div(class: "flex items-center justify-between") do
          div(class: "flex items-center space-x-3") do
            cached_icon :category
            link_to(category.name, category_path(category), id: "show_category_#{category.id}",
                                                            class: "text-lg font-semibold underline underline-offset-[3px]",
                                                            data: { turbo_frame: "_top", turbo_prefetch: false })
          end

          status_badge
        end
      end

      div(class: "p-4") do
        div(class: "grid grid-cols-2 gap-4 my-2") do
          div(class: "space-y-1") do
            div(class: "flex items-center text-sm font-medium text-slate-500") do
              cached_icon :number
              span(class: "ml-2") { pluralise_model(CardTransaction, 2) }
            end

            div(class: "flex items-center") { span(class: "text-sm font-semibold text-slate-800") { category.card_transactions_count } }
          end

          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :money
              span(class: "text-sm font-medium text-slate-500") { model_attribute(CardTransaction, :total_amount) }
            end

            div(class: "flex items-center") do
              span(class: "text-sm font-semibold text-slate-800 mr-auto") { from_cent_based_to_float(category.card_transactions_total, "R$") }
            end
          end
        end

        div(class: "grid grid-cols-2 gap-4 my-2") do
          div(class: "space-y-1") do
            div(class: "flex items-center text-sm font-medium text-slate-500") do
              cached_icon :number
              span(class: "ml-2") { pluralise_model(CashTransaction, 2) }
            end

            div(class: "flex items-center") { span(class: "text-sm font-semibold text-slate-800") { category.cash_transactions_count } }
          end

          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :money
              span(class: "text-sm font-medium text-slate-500") { model_attribute(CashTransaction, :total_amount) }
            end

            div(class: "flex items-center") do
              span(class: "text-sm font-semibold text-slate-800 mr-auto") { from_cent_based_to_float(category.cash_transactions_total, "R$") }
            end
          end
        end

        div(class: "mt-4 flex justify-end gap-2 border-t border-slate-200 pt-3") do
          Button(
            link: search_card_transactions_path(card_transaction: { category_id: category.id }, all_month_years: true),
            variant: :outline,
            class: "border-slate-300 text-slate-700 hover:bg-slate-100",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          ) do
            span(class: "inline-flex items-center gap-2") do
              cached_icon(:jump_to)
              plain pluralise_model(CardTransaction, 2)
            end
          end

          Button(
            link: cash_transactions_path(cash_transaction: { category_id: category.id }, all_month_years: true, mobile: true),
            variant: :outline,
            class: "border-slate-300 text-slate-700 hover:bg-slate-100",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          ) do
            span(class: "inline-flex items-center gap-2") do
              cached_icon(:jump_to)
              plain pluralise_model(CashTransaction, 2)
            end
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
    colour = category.active? ? "bg-emerald-100 text-emerald-800" : "bg-slate-200 text-slate-700"

    span(class: "rounded-full px-2.5 py-1 text-xs font-semibold uppercase tracking-wide #{colour}") do
      model_attribute(Category, "statuses.#{category.active? ? :active : :inactive}")
    end
  end
end
