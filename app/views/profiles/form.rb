# frozen_string_literal: true

class Views::Profiles::Form < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper
  include ComponentsHelper

  attr_reader :profile, :preference, :user_bank_accounts, :user_cards

  def initialize(profile:, preference:, user_bank_accounts:, user_cards:)
    @profile = profile
    @preference = preference
    @user_bank_accounts = user_bank_accounts
    @user_cards = user_cards
  end

  def view_template
    form_with(model: profile, url: profile_path, method: :patch, id: :profile_form, data: { turbo: false },
              class: "contents text-slate-900 dark:text-slate-100") do |form|
      div(class: "lg:flex lg:gap-2 w-full mb-3") do
        div(class: "w-full lg:w-1/2") do
          form.label :first_name, I18n.t("profiles.form.first_name"), class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
          form.text_field :user_profile_first_name, name: "user_profile[first_name]", value: profile&.first_name, class: input_class_without_icon, autofocus: true
        end
        div(class: "w-full lg:w-1/2") do
          form.label :last_name, I18n.t("profiles.form.last_name"), class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
          form.text_field :user_profile_last_name, name: "user_profile[last_name]", value: profile&.last_name, class: input_class_without_icon
        end
      end

      div(class: "lg:flex lg:gap-2 w-full mb-6") do
        div(class: "w-full lg:w-1/2") do
          form.label :locale, I18n.t("profiles.form.locale"), class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
          form.select :user_profile_locale, [ [ "English", "en" ], [ "Brazilian Portuguese", "pt-BR" ] ], { selected: profile&.locale },
                      { name: "user_profile[locale]", class: input_class_without_icon }
        end
        div(class: "w-full lg:w-1/2") do
          form.label :timezone, I18n.t("profiles.form.timezone"), class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
          form.select :user_profile_timezone, [ %w[UTC UTC] ], { selected: profile&.timezone || "UTC" },
                      { name: "user_profile[timezone]", class: input_class_without_icon }
        end
      end

      div(class: "grid grid-cols-1 md:grid-cols-2 gap-4 mb-6") do
        render_preference_select(form, :theme, UserPreference.themes.keys.map { |k| [ k.titleize, k ] })
        render_preference_select(form, :landing_page, landing_page_options)
        render_preference_select(form, :exchange_default_bound_type, UserPreference.exchange_default_bound_types.keys.map { |k| [ k.titleize, k ] })
        render_preference_select(form, :row_color_mode, UserPreference.row_color_modes.keys.map { |k| [ k.titleize, k ] })
        render_preference_select(form, :default_card_transaction_date_order, UserPreference.default_card_transaction_date_orders.keys.map { |k| [ k.titleize, k ] })
        render_preference_select(form, :default_cash_transaction_date_order, UserPreference.default_cash_transaction_date_orders.keys.map { |k| [ k.titleize, k ] })

        render_preference_select_with_custom_label(form, :default_cash_transaction_user_bank_account_id, I18n.t("profiles.form.default_cash_account"),
                                                   user_bank_accounts.map { |acc| [ acc.user_bank_account_name, acc.id ] }, include_blank: true)
      end

      div(class: "flex w-full flex-col gap-3 mt-4") do
        button(type: :submit,
               class: "w-64 border-sky-900 bg-sky-500 text-white hover:border-sky-500 hover:bg-sky-100 " \
                      "hover:text-sky-900 rounded p-2") do
          I18n.t("profiles.form.update")
        end
      end
    end
  end

  private

  def render_preference_select(form, field, options_list, include_blank: false)
    render_preference_select_with_custom_label(form, field, field.to_s.humanize.downcase, options_list, include_blank: include_blank)
  end

  def render_preference_select_with_custom_label(form, field, label_text, options_list, include_blank: false)
    div(class: "w-full") do
      form.label field, label_text, class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
      form.select field, options_list, { selected: preference.public_send(field), include_blank: include_blank },
                  { name: "user_preference[#{field}]",
                    class: "w-full bg-white dark:bg-slate-900 border border-slate-300 " \
                           "dark:border-slate-700 rounded p-2 text-slate-900 dark:text-slate-100" }
    end
  end

  def landing_page_options
    options = [
      %w[Cash cash_transactions],
      %w[Balance balance]
    ]

    user_cards.each do |card|
      options << [ "Card: #{card.user_card_name}", "card_transactions_#{card.id}" ]
    end

    options
  end
end
