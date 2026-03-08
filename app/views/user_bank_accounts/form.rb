# frozen_string_literal: true

class Views::UserBankAccounts::Form < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper
  include ComponentsHelper

  attr_reader :current_user, :user_bank_account, :banks

  def initialize(current_user:, user_bank_account:, banks:)
    @current_user = current_user
    @user_bank_account = user_bank_account
    @banks = banks
  end

  def view_template
    turbo_frame_tag dom_id(user_bank_account) do
      form_url = user_bank_account.persisted? ? user_bank_account_path(user_bank_account) : user_bank_accounts_path

      form_with(model: user_bank_account, url: form_url, id: :form, class: "contents text-black", data: { controller: "reactive-form" }) do |form|
        form.hidden_field :user_id, value: current_user.id

        div(class: "w-full mb-6") do
          form.text_field(
            :user_bank_account_name,
            class: outdoor_input_class,
            autofocus: true,
            autocomplete: :off,
            data: { controller: "blinking-placeholder", text: model_attribute(user_bank_account, :user_bank_account_name) }
          )
        end

        div(class: "lg:flex lg:gap-2 w-full mb-3") do
          div(id: "hw_user_bank_account_bank_id", class: "hw-cb w-full lg:w-4/12 bank-icon") do
            bold_label(form, :bank_id, "user_bank_account_bank_id")
            plain form.combobox(
              :bank_id,
              banks,
              mobile_at: "360px",
              include_blank: false,
              placeholder: action_attribute(:select, user_bank_account, :bank_id)
            )
          end

          div(class: "w-full lg:w-4/12") do
            bold_label(form, :agency_number)
            TextField(form, :agency_number, type: :number, svg: :number, min: 1, max: 9999, class: "font-graduate")
          end

          div(class: "w-full lg:w-4/12") do
            bold_label(form, :account_number)
            TextField(form, :account_number, type: :number, svg: :number, min: 1, max: 999_999_999, class: "font-graduate")
          end
        end

        bold_label(form, :active)

        div(class: "pb-3") do
          form.checkbox :active,
                        class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500",
                        checked: user_bank_account.new_record? || user_bank_account.active
        end

        div(class: "w-full") { render RubyUI::Button.new(type: :submit, variant: :purple) { action_model(:submit, user_bank_account) } }

        if user_bank_account.persisted?
          div(class: "w-full") do
            render RubyUI::Button.new(
              id: "delete_user_bank_account_#{user_bank_account.id}",
              type: :submit,
              variant: :destructive,
              link: user_bank_account_path(user_bank_account),
              data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }
            ) { action_model(:destroy, user_bank_account) }
          end
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end
end
