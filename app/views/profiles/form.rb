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
    form_with(model: profile, url: profile_path, method: :patch, id: :profile_form, data: { turbo: false }, class: "contents text-slate-900 dark:text-slate-100") do |form|
      div(class: "w-full mb-6") do
        form.label :display_name, "display name", class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
        form.text_field :user_profile_display_name, name: "user_profile[display_name]", value: profile&.display_name, class: outdoor_input_class, autofocus: true
      end

      div(class: "lg:flex lg:gap-2 w-full mb-3") do
        div(class: "w-full lg:w-1/2") do
          form.label :first_name, "first name", class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
          form.text_field :user_profile_first_name, name: "user_profile[first_name]", value: profile&.first_name, class: outdoor_input_class
        end
        div(class: "w-full lg:w-1/2") do
          form.label :last_name, "last name", class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
          form.text_field :user_profile_last_name, name: "user_profile[last_name]", value: profile&.last_name, class: outdoor_input_class
        end
      end

      div(class: "lg:flex lg:gap-2 w-full mb-6") do
        div(class: "w-full lg:w-1/2") do
          form.label :locale, "locale", class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
          form.text_field :user_profile_locale, name: "user_profile[locale]", value: profile&.locale, class: outdoor_input_class
        end
        div(class: "w-full lg:w-1/2") do
          form.label :timezone, "timezone", class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
          form.text_field :user_profile_timezone, name: "user_profile[timezone]", value: profile&.timezone, class: outdoor_input_class
        end
      end

      h3(class: "text-lg font-bold mb-4") { "Preferences" }

      div(class: "grid grid-cols-1 md:grid-cols-2 gap-4 mb-6") do
        render_preference_select(form, :theme, UserPreference.themes.keys.map { |k| [ k.titleize, k ] })
        render_preference_select(form, :landing_page, landing_page_options)
        render_preference_select(form, :page_density, UserPreference.page_densities.keys.map { |k| [ k.titleize, k ] })
        render_preference_select(form, :date_time_presentation, UserPreference.date_time_presentations.keys.map { |k| [ k.titleize, k ] })
        render_preference_select(form, :exchange_default_bound_type, UserPreference.exchange_default_bound_types.keys.map { |k| [ k.titleize, k ] })
        render_preference_select(form, :row_color_mode, UserPreference.row_color_modes.keys.map { |k| [ k.titleize, k ] })

        render_preference_select(form, :default_account_id, user_bank_accounts.map { |acc| [ acc.user_bank_account_name, acc.id ] }, include_blank: true)
        render_preference_select(form, :default_card_id, user_cards.map { |card| [ card.user_card_name, card.id ] }, include_blank: true)
        render_preference_select(form, :default_cash_transaction_user_bank_account_id,
                                 user_bank_accounts.map { |acc| [ acc.user_bank_account_name, acc.id ] }, include_blank: true)
      end

      div(class: "flex w-full flex-col gap-3 mt-4") do
        button(type: :submit,
               class: "w-64 border-sky-900 bg-sky-500 text-white hover:border-sky-500 hover:bg-sky-100 " \
                      "hover:text-sky-900 rounded p-2") do
          "Update Profile"
        end
      end
    end
  end

  private

  def render_preference_select(form, field, options_list, include_blank: false)
    div(class: "w-full") do
      form.label field, field.to_s.humanize.downcase, class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400"
      form.select field, options_list, { selected: preference.public_send(field), include_blank: include_blank },
                  { name: "user_preference[#{field}]",
                    class: "w-full bg-white dark:bg-slate-900 border border-slate-300 " \
                           "dark:border-slate-700 rounded p-2 text-slate-900 dark:text-slate-100" }
    end
  end

  def landing_page_options
    options = [
      ["Cash", "cash_transactions"],
      ["Balance", "balance"]
    ]

    user_cards.each do |card|
      options << ["Card: #{card.user_card_name}", "card_transactions_#{card.id}"]
    end

    options
  end
end
