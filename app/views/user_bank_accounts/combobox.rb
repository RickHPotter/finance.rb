# frozen_string_literal: true

class Views::UserBankAccounts::Combobox < Views::Base
  include TranslateHelper

  attr_reader :name, :user_bank_accounts, :selected_user_bank_account_ids

  def initialize(name:, user_bank_accounts:, selected_user_bank_account_ids: [])
    @name = name
    @user_bank_accounts = user_bank_accounts
    @selected_user_bank_account_ids = selected_user_bank_account_ids
  end

  def view_template
    Combobox(term: pluralise_model(UserBankAccount, 2), class: "w-full", data: { ruby_ui__combobox_reorder_value: true }) do
      ComboboxTrigger(placeholder: pluralise_model(UserBankAccount, 2))

      ComboboxPopover do
        div(class: "my-1") do
          ComboboxSearchInput(placeholder: action_message(:type))
        end

        ComboboxList do
          ComboboxEmptyState { I18n.t(:rows_not_found) }

          ComboboxItem(class: "mt-1") do
            ComboboxToggleAllCheckbox(name: "user_bank_account_toggle_all", value: action_message(:all))
            span { action_message(:select_all) }
          end

          user_bank_accounts.each do |user_bank_account_name, id|
            ComboboxItem do
              ComboboxCheckbox(
                name:,
                value: id,
                checked: selected_user_bank_account_ids.include?(id.to_s),
                data: {
                  ruby_ui__combobox_target: "input",
                  action: "change->ruby-ui--combobox#inputChanged change->reactive-form#submitWithDelay",
                  text: user_bank_account_name
                }
              )
              span { user_bank_account_name }
            end
          end
        end
      end
    end
  end
end
