# frozen_string_literal: true

class Views::CashTransactions::Show < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper

  attr_reader :cash_transaction

  def initialize(cash_transaction:)
    @cash_transaction = cash_transaction
  end

  def view_template
    render_pay_modal

    turbo_frame_tag :center_container do
      div(class: show_shell_class) do
        dashboard_header

        div(class: "mt-6 space-y-4") do
          summary_grid
          installments_section
          card_bound_projection_exchanges_section
          exchanges_section
          links_section
        end
      end
    end
  end

  private

  def dashboard_header
    div(class: "flex flex-col gap-5 border-b border-slate-200 pb-5 dark:border-slate-700 lg:flex-row lg:items-start lg:justify-between") do
      div(class: "min-w-0 text-left") do
        h1(class: "text-3xl font-black tracking-tight text-slate-950 dark:text-slate-100 sm:text-4xl") { cash_transaction.description }
        render_scenario_badge

        div(class: "mt-3 flex flex-wrap items-center gap-2") do
          status_badge
          special_badges
        end

        p(class: "mt-3 max-w-3xl text-sm leading-6 text-slate-600 dark:text-slate-400") { cash_transaction.comment } if cash_transaction.comment.present?
      end

      div(class: "grid grid-cols-3 gap-2 [&>*:only-child]:col-span-3 [&>*:nth-child(4):last-child]:col-start-2 sm:flex sm:flex-wrap lg:justify-end") do
        dashboard_action(I18n.t("audit.actions.history"), record_audit_versions_path(item_type: "CashTransaction", item_id: cash_transaction.id), variant: :outline)
        dashboard_action(action_message(:edit), edit_cash_transaction_path(editable_cash_transaction), variant: :edit)
        dashboard_action(action_message(:duplicate), duplicate_cash_transaction_path(cash_transaction), variant: :duplicate) if duplicate_allowed?
        pay_action_button
        destroy_action
      end
    end
  end

  def summary_grid
    section_card(I18n.t("dashboards.sections.summary")) do
      div(class: "grid gap-3 sm:grid-cols-2 xl:grid-cols-4") do
        dashboard_stat(model_attribute(CashTransaction, :price), money(cash_transaction.price), emphasis: true)
        dashboard_stat(model_attribute(CashTransaction, :date), localized_date(cash_transaction.date))
        dashboard_stat(model_attribute(CashTransaction, :month), I18n.l(cash_transaction.date, format: "%B %Y"))
        dashboard_stat(model_attribute(CashTransaction, :user_bank_account_id), account_name)
      end

      div(class: "mt-4 grid gap-3 border-t border-slate-200 pt-4 dark:border-slate-700 xl:grid-cols-2") do
        allocation_group(model_attribute(CashTransaction, :categories), categories.map(&:name))
        allocation_group(model_attribute(CashTransaction, :entities), entities.map(&:name))
      end
    end
  end

  def installments_section
    section_card(I18n.t("dashboards.sections.installments")) do
      if mobile?
        div(class: "space-y-3") do
          installments.each do |installment|
            installment_mobile_card(installment)
          end
        end
      else
        div(class: "overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-700") do
          div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-2xs font-bold uppercase tracking-[0.18em] text-white") do
            span(class: "col-span-1 text-center") { model_attribute(CashInstallment, :number) }
            span(class: "col-span-3") { model_attribute(CashTransaction, :month) }
            span(class: "col-span-3") { model_attribute(CashInstallment, :date) }
            span(class: "col-span-1 text-center") { model_attribute(CashInstallment, :paid) }
            span(class: "col-span-2 text-right") { model_attribute(CashInstallment, :price) }
            span(class: "col-span-2 text-right") { model_attribute(CashInstallment, :balance) }
          end

          installments.each do |installment|
            installment_row(installment)
          end
        end
      end
    end
  end

  def links_section
    section_card("Links and References") do
      div(class: "space-y-2") do
        if cash_transaction.subscription.present?
          link_item(model_attribute(CashTransaction, :subscription_id), cash_transaction.subscription&.description,
                    edit_subscription_path(cash_transaction.subscription))
        end
        reference_link_item
        piggy_bank_link_item
        descendants_link_item
        special_link_item
        empty_links_state if dashboard_links_empty?
      end
    end
  end

  def exchanges_section
    section_card(I18n.t("dashboards.card_transactions.exchanges")) do
      if exchange_entity_transactions.present?
        div(class: "space-y-2") do
          exchange_entity_transactions.each do |entity_transaction|
            exchange_entity_transaction_card(entity_transaction)
          end
        end
      else
        empty_state
      end
    end
  end

  def card_bound_projection_exchanges_section
    return unless card_bound_exchange_return?

    section_card(I18n.t("cash_transactions.exchange_projection.title")) do
      div(class: "space-y-4") do
        card_bound_projection_summary
        card_bound_projection_fix_action if card_bound_projection_fixable?

        if projection_exchanges.present?
          if mobile?
            div(class: "space-y-2") do
              projection_exchanges.each { |exchange| projection_exchange_mobile_card(exchange) }
            end
          else
            div(class: "overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-700") do
              div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-2xs font-bold uppercase tracking-[0.18em] text-white") do
                span(class: "col-span-1 text-center") { I18n.t("cash_transactions.exchange_projection.number") }
                span(class: "col-span-3") { model_attribute(Exchange, :month_year) }
                span(class: "col-span-3") { model_attribute(CardInstallment, :date) }
                span(class: "col-span-2") { I18n.t("cash_transactions.exchange_projection.entity") }
                span(class: "col-span-1 text-center") { I18n.t("cash_transactions.exchange_projection.source") }
                span(class: "col-span-2 text-right") { model_attribute(Exchange, :price) }
              end

              projection_exchanges.each { |exchange| projection_exchange_row(exchange) }
            end
          end
        else
          empty_state
        end
      end
    end
  end

  def section_card(title, &)
    section(class: "rounded-2xl border border-slate-200 bg-slate-50/80 p-3 dark:border-slate-700 dark:bg-slate-950/70 sm:rounded-3xl sm:p-4",
            data: { controller: "show-section-card", show_section_card_open_value: true }) do
      button(type: :button, class: "flex w-full items-center justify-between gap-3 text-left",
             data: { action: "show-section-card#toggle", show_section_card_target: "button" }) do
        h2(class: "text-xs font-black uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400") { title }
        span(class: "text-lg font-semibold leading-none text-slate-500 dark:text-slate-400", data: { show_section_card_target: "icon" }) { "−" }
      end

      div(class: "mt-4", data: { show_section_card_target: "content" }, &)
    end
  end

  def dashboard_stat(label, value, emphasis: false)
    div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") { label }
      p(class: "#{emphasis ? 'text-xl sm:text-2xl' : 'text-base sm:text-lg'} mt-2 font-bold text-slate-950 dark:text-slate-100") { value.to_s }
    end
  end

  def installment_row(installment)
    div(class: "grid grid-cols-12 items-center border-t px-4 py-3 text-sm #{installment_row_class(installment)}") do
      span(class: "col-span-1 text-center") { pretty_installments(installment.number, installment.cash_installments_count) }
      span(class: "col-span-3 font-semibold text-slate-950") { installment.month_year }
      span(class: "col-span-3 text-slate-700") { localized_date(installment.date) }
      span(class: "col-span-1 flex justify-center") { installment_status_badge(installment) }
      span(class: "col-span-2 text-right font-bold text-slate-950") { money(installment.price) }
      span(class: "col-span-2 text-right font-bold text-slate-950") { money(installment.balance) }
    end
  end

  def installment_mobile_card(installment)
    div(class: "overflow-hidden rounded-xl border #{installment_mobile_card_class(installment)}") do
      div(class: "p-3") do
        div(class: "grid grid-cols-3 items-center gap-3") do
          div(class: "flex justify-start") do
            p(class: "inline-flex rounded-md border border-slate-300 bg-white/85 px-2 py-1 text-2xs font-black uppercase tracking-[0.16em] text-slate-700") do
              pretty_installments(installment.number, installment.cash_installments_count)
            end
          end

          div(class: "flex justify-center") do
            installment_status_badge(installment)
          end

          p(class: "text-right text-sm font-bold text-slate-950") { localized_date(installment.date) }
        end

        hr(class: "my-3 border-slate-300")

        p(class: "text-center text-sm font-bold text-slate-950") { installment.month_year }

        hr(class: "my-3 border-slate-200")

        div(class: "grid grid-cols-2 gap-3") do
          div(class: "rounded-lg border border-inherit px-3 py-2 text-left") do
            compact_installment_stat(model_attribute(CashInstallment, :price), money(installment.price), emphasis: true)
          end

          div(class: "rounded-lg border border-inherit px-3 py-2 text-right") do
            compact_installment_stat(model_attribute(CashInstallment, :balance), money(installment.balance), emphasis: true)
          end
        end
      end
    end
  end

  def allocation_group(label, names)
    div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") { label }

      if names.empty?
        p(class: "mt-2 text-sm text-slate-500") { I18n.t("dashboards.empty") }
      else
        div(class: "mt-3 flex flex-wrap justify-center gap-2") do
          if label == model_attribute(CashTransaction, :categories)
            categories.each do |category|
              span(
                class: "flex min-h-12 items-center justify-center break-words rounded-sm border border-black px-2 py-1 text-center text-sm text-black",
                style: "background: #{category.hex_colour}",
                title: category.name
              ) { category.name }
            end
          else
            entities.each do |entity|
              div(
                class: entity_chip_class,
                title: entity.entity_name
              ) do
                image_tag(asset_path("avatars/#{entity.avatar_name}"), class: "h-6 w-6 rounded-full") if entity.avatar_name.present?
                span(class: "break-words") { entity.entity_name }
              end
            end
          end
        end
      end
    end
  end

  def status_badge
    span(class: "rounded-full px-3 py-1 text-xs font-black uppercase tracking-[0.16em] #{paid_state_class}") do
      paid_state_label
    end
  end

  def special_badges
    special_labels.each do |label|
      span(class: "rounded-full border border-amber-300 bg-amber-100 px-3 py-1 text-xs font-bold uppercase tracking-[0.14em] text-amber-900") { label }
    end
  end

  def dashboard_action(label, href, variant:)
    Button(link: href, variant: dashboard_action_variant(variant), class: dashboard_action_class(variant), data: { turbo_frame: "_top", turbo_prefetch: false }) do
      label
    end
  end

  def pay_action_button
    return if payable_installment.blank?

    Button(type: :button, variant: dashboard_action_variant(:pay), class: dashboard_action_class(:pay),
           data: { modal_target: "cashInstallmentModal_#{payable_installment.id}", modal_toggle: "cashInstallmentModal_#{payable_installment.id}" }) do
      model_attribute(payable_installment, :pay)
    end
  end

  def destroy_action
    return unless cash_transaction.can_be_destroyed?

    LinkWithConfirmation(
      id: "cash_transaction_dashboard_destroy_#{cash_transaction.id}",
      text: action_message(:destroy),
      link_params: {
        href: cash_transaction_path(cash_transaction),
        variant: :destructive,
        id: "delete_cash_transaction_#{cash_transaction.id}",
        class: dashboard_action_class(:destroy),
        data: { turbo_method: :delete, turbo_frame: "_top" }
      }
    )
  end

  def dashboard_action_class(variant)
    default = "border-slate-300 text-slate-700 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800"
    return default if %i[primary outline].include?(variant)

    case variant
    when :edit then "border-sky-500 bg-sky-100 text-sky-900 hover:border-sky-400 hover:bg-sky-500 hover:text-white"
    when :duplicate then "border-orange-500 bg-orange-100 text-orange-900 hover:border-orange-400 hover:bg-orange-500 hover:text-white"
    when :pay then "border-green-500 bg-green-100 text-green-900 hover:border-green-400 hover:bg-green-500 hover:text-white"
    when :destroy then "border-red-500 bg-red-100 text-red-900 hover:border-red-400 hover:bg-red-500 hover:text-white"
    else default
    end
  end

  def dashboard_action_variant(variant)
    return :purple if variant == :edit

    :outline
  end

  def cash_index_path
    cash_transactions_path(
      default_year: cash_transaction.year,
      active_month_years: active_month_years_param(cash_transaction.year, cash_transaction.month),
      cash_transaction: { user_bank_account_id: cash_transaction.user_bank_account_id }
    )
  end

  def active_month_years_param(year, month)
    [ Date.new(year, month, 1).strftime("%Y%m").to_i ].to_json
  end

  def link_item(label, value, href)
    link_to href, class: link_card_class,
                  data: { turbo_frame: "_top", turbo_prefetch: false } do
      p(class: "text-2xs font-bold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") { label }
      p(class: "mt-1 truncate text-sm font-bold text-slate-950 dark:text-slate-100") { value }
    end
  end

  def reference_link_item
    reference = dashboard_reference
    return if reference.blank?

    link_item(I18n.t("dashboards.cash_transactions.reference"), reference.description, reference_path_for(reference))
  end

  def piggy_bank_link_item
    if cash_transaction.piggy_bank.present?
      linked_return = cash_transaction.piggy_bank.return_cash_transaction
      return if linked_return.blank?

      link_item(I18n.t("piggy_banks.linked_return"), linked_return.description, cash_transaction_path(linked_return))
    elsif cash_transaction.piggy_bank_return_links.present?
      link_item(
        I18n.t("piggy_banks.sources"),
        I18n.t("piggy_banks.contributions", count: cash_transaction.piggy_bank_return_links.size),
        edit_cash_transaction_path(cash_transaction)
      )
    end
  end

  def descendants_link_item
    return if reference_descendants.empty?

    p(class: empty_link_card_class) do
      I18n.t("dashboards.cash_transactions.reference_descendants", count: reference_descendants.count)
    end
  end

  def show_shell_class
    "min-h-[calc(100svh-12rem)] rounded-2xl border border-slate-200 bg-white p-3 shadow-sm " \
      "dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:shadow-none sm:rounded-3xl sm:p-6"
  end

  def entity_chip_class
    "flex min-h-12 items-center gap-2 rounded-lg border border-slate-400 bg-white px-2 py-1 text-sm text-black " \
      "dark:border-slate-600 dark:bg-slate-900 dark:text-slate-100"
  end

  def link_card_class
    "block rounded-2xl border border-slate-200 bg-white px-4 py-3 transition hover:border-slate-400 " \
      "dark:border-slate-700 dark:bg-slate-900 dark:hover:border-slate-500"
  end

  def empty_link_card_class
    "rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700 " \
      "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300"
  end

  def exchange_entity_transaction_card(entity_transaction)
    div(class: "rounded-2xl border border-slate-200 bg-white px-3 py-3 dark:border-slate-700 dark:bg-slate-900 sm:px-4") do
      if mobile?
        div(class: "space-y-2") do
          div(class: "flex min-w-0 items-center gap-2") do
            if entity_transaction.entity&.avatar_name.present?
              image_tag(asset_path("avatars/#{entity_transaction.entity.avatar_name}"),
                        class: "h-8 w-8 rounded-full")
            end
            span(class: "break-words text-sm font-bold text-slate-950 dark:text-slate-100") { entity_transaction.entity.entity_name }
          end

          div(class: "flex flex-wrap items-center gap-2") do
            exchange_entity_role_badge(entity_transaction)
            exchange_entity_bound_badge(entity_transaction)
            exchange_entity_summary_badge(exchange_entity_summary_text(entity_transaction))
          end
        end
      else
        div(class: "flex items-start gap-3") do
          div(class: "flex min-w-0 items-start gap-2") do
            if entity_transaction.entity&.avatar_name.present?
              image_tag(asset_path("avatars/#{entity_transaction.entity.avatar_name}"),
                        class: "h-8 w-8 rounded-full")
            end

            div(class: "min-w-0") do
              div(class: "flex flex-wrap items-center gap-2") do
                span(class: "truncate text-sm font-bold text-slate-950") { entity_transaction.entity.entity_name }
                exchange_entity_role_badge(entity_transaction)
                exchange_entity_bound_badge(entity_transaction)
                exchange_entity_summary_badge(exchange_entity_summary_text(entity_transaction))
              end
            end
          end
        end
      end

      if entity_transaction.exchanges.present?
        if mobile?
          div(class: "mt-3 space-y-2") do
            entity_transaction.exchanges.order(:number, :date).each do |exchange|
              exchange_mobile_card(exchange)
            end
          end
        else
          div(class: "mt-3 overflow-hidden rounded-xl border border-slate-200") do
            div(class: "grid grid-cols-12 bg-slate-950 px-3 py-2 text-2xs font-bold uppercase tracking-[0.16em] text-white") do
              span(class: "col-span-2 text-center") { model_attribute(CardInstallment, :number) }
              span(class: "col-span-4") { model_attribute(Exchange, :month_year) }
              span(class: "col-span-4") { model_attribute(CardInstallment, :date) }
              span(class: "col-span-2 text-right") { model_attribute(Exchange, :price) }
            end

            entity_transaction.exchanges.order(:number, :date).each do |exchange|
              exchange_row(exchange)
            end
          end
        end
      else
        p(class: "mt-3 text-sm text-slate-500") { exchange_payer_entity_transaction?(entity_transaction) ? "No exchange rows yet." : I18n.t("dashboards.empty") }
      end
    end
  end

  def exchange_row(exchange)
    href = exchange.cash_transaction.present? ? cash_transaction_path(exchange.cash_transaction) : nil
    row_classes = "grid grid-cols-12 items-center border-t border-slate-200 px-3 py-2 text-sm #{exchange_row_class(exchange)}"

    if href.present?
      link_to href, class: "#{row_classes} transition hover:brightness-95", data: { turbo_frame: "_top", turbo_prefetch: false } do
        exchange_row_content(exchange)
      end
    else
      div(class: row_classes) do
        exchange_row_content(exchange)
      end
    end
  end

  def exchange_mobile_card(exchange)
    href = exchange.cash_transaction.present? ? cash_transaction_path(exchange.cash_transaction) : nil
    classes = "rounded-xl border border-inherit px-3 py-2 #{exchange_row_class(exchange)}"

    if href.present?
      link_to href, class: "#{classes} block transition hover:brightness-95", data: { turbo_frame: "_top", turbo_prefetch: false } do
        exchange_mobile_card_content(exchange)
      end
    else
      div(class: classes) do
        exchange_mobile_card_content(exchange)
      end
    end
  end

  def exchange_mobile_card_content(exchange)
    div(class: "flex items-start gap-3") do
      p(class: "rounded-md border border-slate-300 bg-white/80 px-2 py-1 text-2xs font-black uppercase tracking-[0.16em] text-slate-700") do
        exchange.number
      end
    end

    div(class: "mt-3 grid grid-cols-3 gap-2") do
      compact_installment_stat(model_attribute(Exchange, :month_year), exchange.month_year)
      compact_installment_stat(model_attribute(CardInstallment, :date), localized_date(exchange.date))
      compact_installment_stat(model_attribute(Exchange, :price), money(exchange.price), emphasis: true)
    end
  end

  def exchange_row_content(exchange)
    span(class: "col-span-2 text-center font-bold text-slate-950") { exchange.number }
    span(class: "col-span-4 font-semibold text-slate-950") { exchange.month_year }
    span(class: "col-span-4 font-semibold text-slate-950") { localized_date(exchange.date) }
    span(class: "col-span-2 text-right font-bold text-slate-950") { money(exchange.price) }
  end

  def card_bound_projection_summary
    div(class: "grid gap-3 sm:grid-cols-3") do
      dashboard_stat(I18n.t("cash_transactions.exchange_projection.transaction_price"), money(cash_transaction.price), emphasis: true)
      dashboard_stat(I18n.t("cash_transactions.exchange_projection.exchanges_total"), money(projection_exchanges_total), emphasis: true)
      dashboard_stat(I18n.t("cash_transactions.exchange_projection.difference"), money(cash_transaction.price - projection_exchanges_total), emphasis: true)
    end
  end

  def card_bound_projection_fix_action
    div(class: "rounded-2xl border border-orange-200 bg-orange-50 px-4 py-3 text-left") do
      p(class: "text-sm font-semibold text-orange-950") { I18n.t("cash_transactions.exchange_projection.mismatch") }
      p(class: "mt-1 text-xs leading-5 text-orange-800") { I18n.t("cash_transactions.exchange_projection.fix_description") }

      div(class: "mt-3") do
        button_to(
          I18n.t("cash_transactions.exchange_projection.fix"),
          fix_exchange_projection_cash_transaction_path(cash_transaction),
          method: :patch,
          form: { data: { turbo: false } },
          data: { turbo: false, turbo_prefetch: false },
          class: "inline-flex items-center justify-center rounded-md border border-orange-500 bg-orange-100 px-4 py-2 text-sm font-bold text-orange-950 " \
                 "shadow-sm transition hover:border-orange-400 hover:bg-orange-500 hover:text-white"
        )
      end
    end
  end

  def projection_exchange_row(exchange)
    div(class: "grid grid-cols-12 items-center border-t border-slate-200 bg-white px-4 py-3 text-sm") do
      projection_exchange_row_content(exchange)
    end
  end

  def projection_exchange_mobile_card(exchange)
    div(class: "rounded-xl border border-slate-200 bg-white px-3 py-2") do
      div(class: "grid grid-cols-3 items-start gap-2") do
        compact_installment_stat(I18n.t("cash_transactions.exchange_projection.number"), exchange.number)
        compact_installment_stat(model_attribute(Exchange, :month_year), exchange.month_year)
        compact_installment_stat(model_attribute(Exchange, :price), money(exchange.price), emphasis: true)
      end

      div(class: "mt-3 grid grid-cols-2 gap-2 border-t border-slate-200 pt-3") do
        compact_installment_stat(model_attribute(CardInstallment, :date), localized_date(exchange.date))
        compact_installment_stat(I18n.t("cash_transactions.exchange_projection.source"), projection_exchange_source_label(exchange))
      end
    end
  end

  def projection_exchange_row_content(exchange)
    span(class: "col-span-1 text-center font-bold text-slate-950") { exchange.number }
    span(class: "col-span-3 font-semibold text-slate-950") { exchange.month_year }
    span(class: "col-span-3 text-slate-700") { localized_date(exchange.date) }
    span(class: "col-span-2 truncate font-semibold text-slate-950") { exchange.entity_transaction&.entity&.entity_name || "-" }
    span(class: "col-span-1 text-center font-semibold text-sky-800") do
      projection_exchange_source_link(exchange)
    end
    span(class: "col-span-2 text-right font-bold text-slate-950") { money(exchange.price) }
  end

  def projection_exchange_source_link(exchange)
    source = exchange.entity_transaction&.transactable
    if source.is_a?(CardTransaction)
      link_to "##{source.id}", card_transaction_path(source), class: "hover:underline", data: { turbo_frame: "_top", turbo_prefetch: false }
    else
      plain "-"
    end
  end

  def special_link_item
    return unless cash_transaction.card_payment? || cash_transaction.card_advance? || cash_transaction.investment?

    p(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700") do
      special_labels.join(" · ")
    end
  end

  def empty_links_state
    p(class: "text-sm text-slate-500") { I18n.t("dashboards.empty") }
  end

  def render_pay_modal
    render Views::CashInstallments::PayModal.new(cash_installment: payable_installment) if payable_installment.present?
  end

  def installments
    @installments ||= cash_transaction.cash_installments.order(:number, :date).to_a
  end

  def categories
    @categories ||= cash_transaction.categories.order(:category_name).to_a
  end

  def entities
    @entities ||= cash_transaction.entities.order(:entity_name).to_a
  end

  def reference_descendants
    @reference_descendants ||= cash_transaction.reference_children(scope: current_context.cash_transactions).to_a
  end

  def exchange_entity_transactions
    @exchange_entity_transactions ||= cash_transaction.entity_transactions.includes(:entity, exchanges: :cash_transaction).sort_by do |entity_transaction|
      [ exchange_payer_entity_transaction?(entity_transaction) ? 0 : 1, entity_transaction.entity.name ]
    end
  end

  def projection_exchanges
    @projection_exchanges ||= cash_transaction.exchanges.includes(entity_transaction: :entity).select(&:card_bound?).select(&:monetary?).sort_by do |exchange|
      [ exchange.year, exchange.month, exchange.number, exchange.date, exchange.id ]
    end
  end

  def card_bound_exchange_return?
    cash_transaction.exchange_return? && projection_exchanges.present?
  end

  def projection_exchanges_total
    @projection_exchanges_total ||= projection_exchanges.sum(&:price)
  end

  def card_bound_projection_mismatch?
    cash_transaction.price != projection_exchanges_total
  end

  def card_bound_projection_fixable?
    card_bound_projection_mismatch? ||
      stale_own_projection_exchanges.present? ||
      out_of_bucket_projection_exchanges.present? ||
      incoming_wrong_owner_projection_exchanges.present? ||
      incoming_stale_projection_exchanges.present? ||
      duplicate_card_bound_projection_transactions.many?
  end

  def out_of_bucket_projection_exchanges
    @out_of_bucket_projection_exchanges ||= projection_exchanges.reject do |exchange|
      exchange.month == cash_transaction.month && exchange.year == cash_transaction.year
    end
  end

  def incoming_wrong_owner_projection_exchanges
    @incoming_wrong_owner_projection_exchanges ||= begin
      group_keys = projection_exchange_group_keys
      if group_keys.empty?
        []
      else
        Exchange.card_bound.monetary.joins(:cash_transaction)
                .where(cash_transactions: { context_id: current_context.id })
                .where.not(cash_transaction_id: cash_transaction.id)
                .includes(entity_transaction: :entity)
                .select { |exchange| incoming_wrong_owner_projection_exchange?(exchange, group_keys) }
      end
    end
  end

  def incoming_wrong_owner_projection_exchange?(exchange, group_keys)
    source = exchange.entity_transaction&.transactable
    return false unless source.is_a?(CardTransaction)
    return false unless group_keys.include?([ source.user_card_id, exchange.entity_transaction.entity_id ])
    return false unless exchange.month == cash_transaction.month && exchange.year == cash_transaction.year

    source_installment = projection_source_installment(exchange)
    source_installment.present? && source_installment.month == cash_transaction.month && source_installment.year == cash_transaction.year
  end

  def projection_exchange_group_keys
    projection_exchanges.filter_map do |exchange|
      source = exchange.entity_transaction&.transactable
      [ source.user_card_id, exchange.entity_transaction.entity_id ] if source.is_a?(CardTransaction)
    end.uniq
  end

  def stale_own_projection_exchanges
    @stale_own_projection_exchanges ||= projection_exchanges.select { |exchange| stale_projection_exchange?(exchange) }
  end

  def incoming_stale_projection_exchanges
    @incoming_stale_projection_exchanges ||= begin
      user_card_ids = projection_exchange_user_card_ids
      if user_card_ids.empty?
        []
      else
        Exchange.card_bound.monetary.joins(:cash_transaction)
                .where(cash_transactions: { context_id: current_context.id })
                .where.not(cash_transaction_id: cash_transaction.id)
                .includes(entity_transaction: :entity)
                .select { |exchange| incoming_stale_projection_exchange?(exchange, user_card_ids) }
      end
    end
  end

  def incoming_stale_projection_exchange?(exchange, user_card_ids)
    source = exchange.entity_transaction&.transactable
    return false unless source.is_a?(CardTransaction)
    return false unless user_card_ids.include?(source.user_card_id)

    source_installment = projection_source_installment(exchange)
    return false if source_installment.blank?
    return false unless source_installment.month == cash_transaction.month && source_installment.year == cash_transaction.year

    stale_projection_exchange?(exchange)
  end

  def stale_projection_exchange?(exchange)
    source_installment = projection_source_installment(exchange)
    return false if source_installment.blank?

    exchange.month != source_installment.month || exchange.year != source_installment.year
  end

  def projection_source_installment(exchange)
    source = exchange.entity_transaction&.transactable
    return unless source.is_a?(CardTransaction)

    source.card_installments.find_by(number: exchange.number)
  end

  def projection_exchange_user_card_ids
    projection_exchanges.filter_map do |exchange|
      source = exchange.entity_transaction&.transactable
      source.user_card_id if source.is_a?(CardTransaction)
    end.uniq
  end

  def duplicate_card_bound_projection_transactions
    @duplicate_card_bound_projection_transactions ||= begin
      user_card_ids = projection_exchange_user_card_ids
      if user_card_ids.empty?
        current_context.cash_transactions.where(id: cash_transaction.id)
      else
        duplicate_ids = current_context.cash_transactions
                                       .exchange_return
                                       .where(
                                         user_id: cash_transaction.user_id,
                                         user_card_id: user_card_ids,
                                         cash_transaction_type: cash_transaction.cash_transaction_type,
                                         description: cash_transaction.description,
                                         month: cash_transaction.month,
                                         year: cash_transaction.year
                                       )
                                       .pluck(:id)
        current_context.cash_transactions.where(id: [ cash_transaction.id, *duplicate_ids ].uniq)
      end
    end
  end

  def projection_exchange_source_label(exchange)
    source = exchange.entity_transaction&.transactable
    source.is_a?(CardTransaction) ? "##{source.id}" : "-"
  end

  def exchange_payer_entity_transaction?(entity_transaction)
    return true if entity_transaction.is_payer?
    return false if entity_transaction.price.to_i.zero?

    entity_transaction.entity.built_in?
  end

  def dashboard_reference
    @dashboard_reference ||= begin
      reference = cash_transaction.reference_transactable
      reference if visible_dashboard_reference?(reference)
    end
  end

  def visible_dashboard_reference?(reference)
    case reference
    when CashTransaction then current_context.cash_transactions.exists?(id: reference.id)
    when CardTransaction then current_context.card_transactions.exists?(id: reference.id)
    when Budget then current_context.budgets.exists?(id: reference.id)
    else false
    end
  end

  def payable_installment
    @payable_installment ||= installments.reject(&:paid?).one? ? installments.reject(&:paid?).first : nil
  end

  def dashboard_links_empty?
    cash_transaction.subscription.blank? &&
      dashboard_reference.blank? &&
      reference_descendants.empty? &&
      !cash_transaction.card_payment? &&
      !cash_transaction.card_advance? &&
      !cash_transaction.investment? &&
      cash_transaction.piggy_bank.blank? &&
      cash_transaction.piggy_bank_return_links.blank?
  end

  def editable_cash_transaction
    cash_transaction
  end

  def exchange_bound_badge(exchange)
    label = exchange.card_bound? ? "Card Bound" : "Standalone"
    classes = exchange.card_bound? ? "bg-sky-200 text-sky-950" : "bg-slate-200 text-slate-900"

    span(class: "rounded-full px-2.5 py-1 text-2xs font-black uppercase tracking-[0.16em] #{classes}") { label }
  end

  def exchange_entity_role_badge(entity_transaction)
    label = exchange_payer_entity_transaction?(entity_transaction) ? "Payer" : "Non-Payer"
    classes = exchange_payer_entity_transaction?(entity_transaction) ? "bg-amber-100 text-amber-900" : "bg-slate-100 text-slate-700"

    span(class: "rounded-full px-2.5 py-1 text-2xs font-black uppercase tracking-[0.16em] #{classes}") { label }
  end

  def exchange_entity_bound_badge(entity_transaction)
    exchange = entity_transaction.exchanges.first
    return if exchange.blank?

    exchange_bound_badge(exchange)
  end

  def exchange_entity_summary_badge(text)
    span(class: "rounded-full bg-slate-100 px-2.5 py-1 text-2xs font-bold uppercase tracking-[0.16em] text-slate-700") { text }
  end

  def exchange_entity_summary_text(entity_transaction)
    if exchange_payer_entity_transaction?(entity_transaction)
      "#{money(entity_transaction.price_to_be_returned)} · #{entity_transaction.exchanges_count}x"
    else
      money(entity_transaction.price)
    end
  end

  def installment_row_class(installment)
    if installment.paid?
      "border-emerald-200 bg-emerald-50 text-emerald-950"
    else
      "border-rose-200 bg-rose-50 text-rose-950"
    end
  end

  def installment_mobile_card_class(installment)
    return "border-slate-200 bg-white" if installment.blank?

    installment.paid? ? "border-emerald-200 bg-emerald-50" : "border-rose-200 bg-rose-50"
  end

  def installment_status_badge(installment)
    span(class: "rounded-full px-2.5 py-1 text-2xs font-black uppercase tracking-[0.16em] #{installment_status_badge_class(installment)}") do
      installment.paid? ? I18n.t("filters.paid_state.paid") : I18n.t("filters.paid_state.pending")
    end
  end

  def installment_status_badge_class(installment)
    installment.paid? ? "bg-emerald-200 text-emerald-950" : "bg-rose-200 text-rose-950"
  end

  def exchange_row_class(exchange)
    exchange.cash_transaction&.paid? ? "bg-emerald-50" : "bg-rose-50"
  end

  def compact_installment_stat(label, value, emphasis: false)
    div do
      p(class: "text-2xs font-bold uppercase tracking-[0.16em] text-slate-500") { label }
      p(class: "#{emphasis ? 'text-sm' : 'text-xs'} mt-1 font-bold text-slate-950") { value }
    end
  end

  def empty_state
    p(class: "text-sm text-slate-500") { I18n.t("dashboards.empty") }
  end

  def duplicate_allowed?
    cash_transaction.can_be_destroyed?
  end

  def special_labels
    [
      (I18n.t("naming_conventions.conventions.investment") if cash_transaction.investment?),
      (I18n.t("naming_conventions.conventions.card_payment") if cash_transaction.card_payment?),
      (I18n.t("naming_conventions.conventions.card_advance") if cash_transaction.card_advance?),
      (I18n.t("naming_conventions.conventions.exchange_return") if cash_transaction.exchange_return?),
      (I18n.t("dashboards.cash_transactions.borrow_return") if cash_transaction.borrow_return?)
    ].compact
  end

  def reference_path_for(reference)
    case reference
    when CashTransaction then cash_transaction_path(reference)
    when CardTransaction then card_transaction_path(reference)
    when Budget then budget_path(reference)
    else "#"
    end
  end

  def paid_state_label
    return I18n.t("filters.paid_state.paid") if installments.all?(&:paid?)
    return I18n.t("dashboards.status.partial") if installments.any?(&:paid?)

    I18n.t("filters.paid_state.pending")
  end

  def paid_state_class
    return "bg-emerald-100 text-emerald-900" if installments.all?(&:paid?)
    return "bg-amber-100 text-amber-900" if installments.any?(&:paid?)

    "bg-rose-100 text-rose-900"
  end

  def paid_label(installment)
    installment.paid? ? I18n.t("filters.paid_state.paid") : I18n.t("filters.paid_state.pending")
  end

  def account_name
    cash_transaction.user_bank_account&.user_bank_account_name || "-"
  end

  def localized_date(value)
    I18n.l(value, format: :short)
  end

  def money(value)
    from_cent_based_to_float(value.to_i, "R$")
  end
end
