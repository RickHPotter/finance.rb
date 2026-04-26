# frozen_string_literal: true

class Views::Investments::MonthYear < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include CacheHelper

  attr_reader :mobile, :month_year, :month_year_str, :investments, :total_amount, :investment_bg_colour

  def initialize(mobile:, month_year:, month_year_str:, investments:, current_user:)
    @month_year = month_year
    @mobile = mobile
    @month_year_str = month_year_str
    @investments = investments
    @total_amount = investments.sum(:price)

    @investment_bg_colour = current_user.categories.built_in.find_by(category_name: "INVESTMENT").hex_colour
  end

  def view_template
    turbo_frame_tag "month_year_container_#{month_year}" do
      if mobile
        render_mobile_month_year
      else
        render_month_year
      end
    end
  end

  def render_mobile_month_year
    div(class: "mb-8", data: { datatable_target: :table }) do
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg px-2 mb-4") do
        render Views::Shared::MonthYearHeader.new(month_year_str:, total_amount:, mobile:)

        if investments.present?
          render_mobile_investments
        else
          div(class: "border-b border-slate-200 py-2 my-2 text-lg") { I18n.t(:rows_not_found) }
        end
      end
    end
  end

  def render_month_year
    div(class: "mb-8", data: { datatable_target: :table }) do
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4") do
        render Views::Shared::MonthYearHeader.new(month_year_str:, total_amount:, mobile:)

        div(class: "bg-white rounded-lg border border-slate-300 shadow-sm overflow-visible") do
          render Views::Shared::TableHeader.new(
            grid_class: "grid grid-cols-7",
            rows: [
              [
                { class: "col-span-2 col-start-2", label: model_attribute(Investment, :description) },
                { class: "flex justify-center", label: model_attribute(Investment, :user_bank_account_id), align: :center },
                { class: "flex justify-center", label: model_attribute(Investment, :investment_type_id), align: :center },
                { class: "flex items-end justify-end", label: model_attribute(Investment, :price), align: :right },
                { class: "flex justify-center", label: I18n.t(:datatable_actions) }
              ]
            ]
          )

          if investments.present?
            render_investments
          else
            div(class: "py-2 text-lg") { I18n.t(:rows_not_found) }
          end

          div(class: "grid grid-cols-7 py-1 bg-slate-200 border-b border-slate-400 rounded-b-lg font-semibold text-black font-graduate") do
            span(class: "py-3 col-span-5 text-center") { "#{model_attribute(Investment, :total_amount)}:" }

            span(class: "py-3 col-start-6 text-end", id: :totalAmount, data: { price: total_amount }) do
              from_cent_based_to_float(total_amount, "R$")
            end
          end
        end
      end
    end
  end

  def render_mobile_investments
    investments.each do |investment|
      turbo_frame_tag dom_id investment do
        div(
          class: "rounded-lg shadow-sm overflow-visible bg-slate-200 my-2 hover:opacity-80 transition-all",
          style: "background-clip: padding-box; background-color: #{investment_bg_colour}",
          data: { id: investment.id, datatable_target: :row }
        ) do
          div(class: "p-4") do
            div(class: "flex items-center justify-between gap-4 w-full text-black text-sm font-semibold") do
              div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
                link_to investment.description,
                        edit_investment_path(investment),
                        id: "edit_investment_#{investment.id}",
                        class: "truncate text-md underline underline-offset-[3px]",
                        data: { turbo_frame: "_top" }

                link_to investment.user_bank_account.user_bank_account_name,
                        new_investment_path(next_day: true, chain_mode: "duplicate", investment: investment.slice(:user_bank_account_id, :investment_type_id)),
                        class: "p-1 rounded-sm bg-white border border-black shrink-0",
                        data: { turbo_frame: "_top" }
              end
            end

            div(class: "py-2 flex items-center justify-center gap-2 hover:opacity-65 min-w-0") do
              if investment.investment_type.nil?
                plain "-"
              else
                div(class: "block truncate text-center px-2 py-1 rounded-sm bg-zinc-700 text-white border text-sm w-full") do
                  investment.investment_type.display_name.upcase
                end
              end
            end

            div(class: "flex items-center justify-between py-2") do
              div(class: "text-xs text-start flex-1 flex items-center") do
                render_action_menu(investment)

                span(class: "whitespace-nowrap pl-2") { I18n.l(investment.date, format: :short) }
              end

              div(class: "whitespace-nowrap") do
                from_cent_based_to_float(investment.price, "R$")
              end
            end
          end
        end
      end
    end
  end

  def render_investments
    investments.each do |investment|
      turbo_frame_tag dom_id investment do
        div(
          class: "grid grid-cols-7 bg-gradient-to-r hover:opacity-80 transition-all",
          style: "background-clip: padding-box; background-color: #{investment_bg_colour}",
          data: { id: investment.id, datatable_target: :row }
        ) do
          div(class: "flex items-center justify-between gap-2 rounded-sm pl-4") do
            date, time = I18n.l(investment.date, format: :shorter).split(",")
            div(class: "grid grid-cols-1 mr-auto") do
              span(class: "rounded-xs text-xs mr-auto") { date }
              span(class: "rounded-xs text-xs mr-auto") { time }
            end
          end

          div(class: "col-span-2 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2 hover:opacity-65") do
            link_to investment.description,
                    edit_investment_path(investment),
                    id: "edit_investment_#{investment.id}",
                    class: "flex-1 truncate text-md underline underline-offset-[3px]",
                    data: { turbo_frame: "_top" }
          end

          div(class: "py-2 flex items-center justify-center gap-2 hover:opacity-65") do
            link_to investment.user_bank_account.user_bank_account_name,
                    new_investment_path(next_day: true, chain_mode: "duplicate", investment: investment.slice(:user_bank_account_id, :investment_type_id)),
                    class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border text-sm underline bg-white border-black text-indigo-600",
                    data: { turbo_frame: "_top" }
          end

          div(class: "py-2 flex items-center justify-center gap-2 hover:opacity-65 min-w-0") do
            if investment.investment_type.nil?
              plain "-"
            else
              title = investment.investment_type.display_name.upcase

              div(class: "block truncate text-center px-2 py-1 rounded-sm bg-zinc-700 text-white border text-sm w-full", title:) do
                title
              end
            end
          end

          div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto hover:opacity-65") do
            from_cent_based_to_float(investment.price, "R$")
          end

          div(class: "py-2 flex items-center justify-center") do
            div(class: "flex items-center justify-center gap-1 px-2") do
              render_duplicate_action(investment)

              LinkWithConfirmation(
                id: investment.id,
                icon: :destroy,
                link_params: {
                  href: investment_path(investment),
                  size: :xs,
                  id: "delete_investment_#{investment.id}",
                  class: destructive_action_button_class,
                  data: { turbo_method: :delete }
                }
              )
            end
          end
        end
      end
    end
  end

  def render_action_menu(investment)
    Popover(options: { trigger: "click", placement: "bottom-start" }, class: "relative z-50 shrink-0") do
      PopoverTrigger(class: "flex") do
        button(
          type: :button,
          id: "investment_actions_#{investment.id}",
          class: action_menu_button_class,
          title: I18n.t("actions_column"),
          aria: { label: I18n.t("actions_column") }
        ) do
          cached_icon(:ellipsis)
        end
      end

      PopoverContent(class: "z-60 opacity-100! min-w-44 p-1") do
        div(class: "flex flex-col gap-1") do
          action_menu_link(action_message(:duplicate), duplicate_investment_path(investment))
          action_menu_destroy_link(investment)
        end
      end
    end
  end

  def action_menu_link(label, href)
    link_to label,
            href,
            class: action_menu_item_class,
            data: { turbo_frame: "_top", turbo_prefetch: false, action: "click->ruby-ui--popover#close" }
  end

  def action_menu_destroy_link(investment)
    LinkWithConfirmation(
      id: "investment_menu_destroy_#{investment.id}",
      text: action_message(:destroy),
      link_params: {
        href: investment_path(investment),
        variant: :ghost,
        id: "delete_investment_#{investment.id}",
        class: action_menu_item_class,
        data: {
          turbo_method: :delete,
          turbo_frame: "_top"
        }
      }
    )
  end

  def action_button_class
    "inline-flex size-6 items-center justify-center rounded-sm border border-slate-300 bg-white text-slate-800 " \
      "shadow-sm transition hover:border-slate-900 hover:bg-slate-900 hover:text-white [&_svg]:size-4"
  end

  def render_duplicate_action(investment)
    link_to(
      duplicate_investment_path(investment),
      id: "duplicate_investment_#{investment.id}",
      class: action_button_class,
      title: action_message(:duplicate),
      aria: { label: action_message(:duplicate) },
      data: { turbo_frame: "_top", turbo_prefetch: false }
    ) do
      cached_icon(:copy)
    end
  end

  def destructive_action_button_class
    "#{action_button_class} border-red-200 text-red-700 hover:border-red-600 hover:bg-red-600 hover:text-white [&_svg]:!text-current"
  end

  def action_menu_button_class
    "rounded-sm bg-white/90 p-0.5 text-slate-900 shadow-sm ring-1 ring-black/20 transition hover:bg-slate-900 hover:text-white [&_svg]:size-4"
  end

  def action_menu_item_class
    "w-full justify-start rounded-md px-3 py-2 text-left text-sm font-semibold text-slate-700 no-underline transition-colors hover:bg-slate-100 hover:no-underline"
  end
end
