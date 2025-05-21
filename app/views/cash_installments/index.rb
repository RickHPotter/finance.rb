# frozen_string_literal: true

class Views::CashInstallments::Index < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper
  include CacheHelper

  attr_reader :mobile, :cash_installments

  def initialize(mobile:, cash_installments:)
    @mobile = mobile
    @cash_installments = cash_installments
  end

  def view_template
    if mobile
      cash_installments.each do |cash_installment|
        render_mobile_cash_installment(cash_installment)
      end
    else
      cash_installments.each do |cash_installment|
        render_cash_installment(cash_installment)
      end
    end
  end

  def render_mobile_cash_installment(cash_installment) # rubocop:disable Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity
    turbo_frame_tag dom_id cash_installment do
      cash_transaction = cash_installment.cash_transaction

      should_display_link_to_pay, icon = should_display_link_to_pay?(cash_installment)

      render Views::CashInstallments::PayModal.new(cash_installment:) if should_display_link_to_pay

      div(class: "relative") do
        div(
          class: "absolute -top-2 right-0 p-1 rounded-t-lg bg-yellow-400 shadow-sm border border-yellow-600 font-lekton font-bold
                  text-black text-sm z-40 #{'animate-pulse' if should_display_link_to_pay}"
        ) do
          from_cent_based_to_float(cash_installment.balance, "R$")
        end
      end

      div(
        class: "rounded-lg shadow-sm overflow-hidden #{cash_transaction.categories&.first&.bg_colour} my-4 #{'animate-pulse' if should_display_link_to_pay}",
        data: { id: cash_installment.id, datatable_target: :row }
      ) do
        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-black text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0 underline underline-offset-[3px]") do
              if cash_transaction.investment?
                default_year = cash_transaction.year
                active_month_years = "[#{Date.new(cash_transaction.year, cash_transaction.month).strftime('%Y%m')}]"
                investment = { user_bank_account_id: cash_transaction.user_bank_account_id }

                link_to cash_transaction.description,
                        investments_path(investment:, default_year:, active_month_years:, format: :turbo_stream),
                        class: "truncate text-md",
                        data: { turbo_frame: :center_container, turbo_prefetch: false }
              elsif cash_transaction.card_payment? || cash_transaction.card_advance?
                card_ = cash_transaction.card_installments.first || CardTransaction.find_by(advance_cash_transaction: cash_transaction)
                default_year = card_.year
                active_month_years = "[#{Date.new(card_.year, card_.month).strftime('%Y%m')}]"

                link_to cash_transaction.description,
                        card_transactions_path(user_card_id: cash_transaction.user_card_id, default_year:, active_month_years:, format: :turbo_stream),
                        class: "truncate text-md",
                        data: { turbo_frame: :center_container, turbo_prefetch: false }
              else
                link_to cash_transaction.description, edit_cash_transaction_path(cash_transaction),
                        id: "edit_cash_transaction_#{cash_transaction.id}",
                        class: "truncate text-md",
                        data: { turbo_frame: :center_container }
              end

              span(class: "flex-shrink p-1 rounded-sm bg-white border border-black #{'opacity-40' if cash_transaction.cash_installments_count == 1}") do
                pretty_installments(cash_installment.number, cash_installment.cash_installments_count)
              end
            end
          end

          div(class: "flex items-center justify-between py-2") do
            div(class: "text-xs text-start flex-1 flex items-center") do
              if should_display_link_to_pay
                button(
                  class: "hover:bg-white hover:text-honda hover:rounded-full hover:scale-160 transition-all duration-200",
                  title: model_attribute(cash_installment, :pay),
                  data: { modal_target: "cashInstallmentModal_#{cash_installment.id}", modal_toggle: "cashInstallmentModal_#{cash_installment.id}" }
                ) do
                  cached_icon(icon)
                end
              else
                button(class: "hover:bg-white hover:text-money hover:rounded-full hover:scale-160 transition-all duration-200",
                       title: model_attribute(cash_installment, :already_paid)) do
                  cached_icon(icon)
                end
              end

              span(class: "whitespace-nowrap pl-2") do
                format = cash_transaction.investment? ? "%B %Y" : :short
                I18n.l(cash_installment.date, format:)
              end
            end

            div(class: "whitespace-nowrap") do
              from_cent_based_to_float(cash_installment.price, "R$")
            end
          end

          div(class: "flex items-center justify-between gap-2") do
            div(class: "flex justify-between gap-2", data: { datatable_target: :category, id: cash_transaction.categories.map(&:id) }) do
              cash_transaction.categories.each do |category|
                span(class: "py-1 rounded-full text-xs font-medium underline underline-offset-[3px]") do
                  category.name
                end
              end
            end

            div(class: "flex justify-between gap-2", data: { datatable_target: :entity, id: cash_transaction.entities.map(&:id) }) do
              cash_transaction.entities.each do |entity|
                span(class: "px-2 py-1 rounded-full text-xs font-medium bg-slate-100 text-black border border-1 border-gray-500") do
                  entity.entity_name
                end
              end
            end
          end
        end
      end
    end
  end

  def render_cash_installment(cash_installment)
    turbo_frame_tag dom_id cash_installment do
      cash_transaction = cash_installment.cash_transaction

      should_display_link_to_pay, icon = should_display_link_to_pay?(cash_installment)

      render Views::CashInstallments::PayModal.new(cash_installment:) if should_display_link_to_pay

      div(
        class: "grid grid-cols-8 border-b border-slate-200 bg-gradient-to-r #{solid_colour_or_gradient(cash_transaction)}
                  hover:opacity-80 #{'animate-pulse' if should_display_link_to_pay}".squish,
        draggable: true,
        data: { id: cash_installment.id,
                datatable_target: :row,
                action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop" }
      ) do
        div(class: "flex items-center justify-between gap-2 rounded-sm text-slate-900 pl-2") do
          if should_display_link_to_pay
            button(
              type: :button,
              class: "hover:bg-white hover:text-honda hover:rounded-full hover:scale-160",
              title: model_attribute(cash_installment, :pay),
              data: { modal_target: "cashInstallmentModal_#{cash_installment.id}", modal_toggle: "cashInstallmentModal_#{cash_installment.id}" }
            ) do
              cached_icon(icon)
            end
          else
            span(class: "hover:bg-white hover:text-money hover:rounded-sm hover:scale-160", title: model_attribute(cash_installment, :already_paid)) do
              cached_icon(icon)
            end
          end

          span(class: "px-1 rounded-sm text-slate-900 mr-auto") do
            format = cash_transaction.investment? ? "%B %Y" : :shorter
            I18n.l(cash_installment.date, format:)
          end
        end

        div(class: "col-span-3 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2  underline underline-offset-[3px]") do
          if cash_transaction.investment?
            default_year = cash_transaction.year
            active_month_years = "[#{Date.new(cash_transaction.year, cash_transaction.month).strftime('%Y%m')}]"
            investment = { user_bank_account_id: cash_transaction.user_bank_account_id }

            link_to cash_transaction.description,
                    investments_path(investment:, default_year:, active_month_years:, format: :turbo_stream),
                    class: "flex-1 truncate text-md",
                    data: { turbo_frame: :center_container, turbo_prefetch: false }
          elsif cash_transaction.card_payment? || cash_transaction.card_advance?
            card_ = cash_transaction.card_installments.first || CardTransaction.find_by(advance_cash_transaction: cash_transaction)
            default_year = card_.year
            active_month_years = "[#{Date.new(card_.year, card_.month).strftime('%Y%m')}]"

            link_to cash_transaction.description,
                    card_transactions_path(user_card_id: cash_transaction.user_card_id, default_year:, active_month_years:, format: :turbo_stream),
                    class: "flex-1 truncate text-md",
                    data: { turbo_frame: :center_container, turbo_prefetch: false }
          else
            link_to cash_transaction.description,
                    edit_cash_transaction_path(cash_transaction),
                    id: "edit_cash_transaction_#{cash_transaction.id}",
                    class: "flex-1 truncate text-md",
                    data: { turbo_frame: :center_container }
          end
          span(class: "p-1 rounded-sm bg-white border border-black flex-shrink-0 #{'opacity-40' if cash_installment.cash_installments_count == 1}") do
            pretty_installments(cash_installment.number, cash_installment.cash_installments_count)
          end
        end

        div(class: "py-2 flex items-center justify-center gap-2", data: { datatable_target: :category, id: cash_transaction.categories.map(&:id) }) do
          cash_transaction.categories.each do |category|
            span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-sm") do
              category.name
            end
          end
        end

        div(class: "py-2 flex items-center justify-center flex-wrap gap-2", data: { datatable_target: :entity, id: cash_transaction.entities.map(&:id) }) do
          cash_transaction.entities.each do |entity|
            span(class: "px-4 rounded-full text-sm bg-purple-100 text-slate-800 border-1 border-black") do
              entity.entity_name
            end
          end
        end

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto") do
          from_cent_based_to_float(cash_installment.price, "R$")
        end

        div(class: "py-2 px-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto") do
          from_cent_based_to_float(cash_installment.balance, "R$")
        end
      end
    end
  end

  def solid_colour_or_gradient(cash_transaction)
    if cash_transaction.categories.count > 1
      return [
        cash_transaction.categories.first.from_bg, *cash_transaction.categories[1..-2].map(&:via_bg),
        cash_transaction.categories.last.to_bg
      ].join(" ")
    end

    cash_transaction.categories.first&.bg_colour
  end

  def should_display_link_to_pay?(cash_installment)
    case [ cash_installment.paid, cash_installment.date > Time.zone.today ]
    in [ true,  _     ] then [ false, :check_square ]
    in [ false, true  ] then [ true,  :warning_octagon ]
    in [ false, false ] then [ true,  :x_circle ]
    end
  end
end
