# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContextHelper do
  subject(:helper_host) do
    host = Class.new do
      include ContextHelper

      attr_accessor :current_user
    end.new
    host.current_user = user
    host
  end

  let(:user) { create(:user, :random) }

  describe "combobox aliases" do
    it "exposes bank, agency, account, and account suffix tokens independently" do
      bank_account = create(
        :user_bank_account,
        :random,
        user:,
        bank: create(:bank, :random, bank_name: "São Banco"),
        agency_number: 1234,
        account_number: 987_654
      )

      helper_host.set_user_bank_accounts
      option = helper_host.instance_variable_get(:@user_bank_accounts).find { |(_label, id, _data)| id == bank_account.id }

      expect(option.third.fetch(:alias)).to eq("sao banco | 1234 | 987654 | 7654")
    end

    it "uses the card brand alias without claiming unavailable last-four data" do
      user_card = create(:user_card, :random, user:, card: create(:card, :random, card_name: "Visa"), user_card_name: "Travel card")

      helper_host.set_user_cards
      option = helper_host.instance_variable_get(:@user_cards).find { |(_label, id, _data)| id == user_card.id }

      expect(option).to eq([ "Travel card", user_card.id, { alias: "visa" } ])
    end

    it "formats category options hierarchically with parent alias tokens for subcategories" do
      parent = create(:category, :random, user:, category_name: "HSH")
      child = create(:category, :random, user:, category_name: "LABOUR", parent_category: parent)

      helper_host.set_categories
      categories = helper_host.instance_variable_get(:@categories)

      parent_option = categories.find { |(_label, id, _data)| id == parent.id }
      child_option = categories.find { |(_label, id, _data)| id == child.id }

      expect(parent_option).to eq([ "HSH", parent.id, { alias: "hsh" } ])
      expect(child_option).to eq([ "HSH / LABOUR", child.id, { alias: "hsh | labour | hsh labour" } ])
    end
  end
end
