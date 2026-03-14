# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasActive, type: :concern do
  describe "[ concern behaviour ]" do
    it "defaults active to true on create" do
      user_bank_account = build(:user_bank_account, active: nil)

      user_bank_account.save!

      expect(user_bank_account.active).to be(true)
    end

    it "provides inactive? based on active" do
      user_bank_account = build(:user_bank_account, active: false)

      expect(user_bank_account.inactive?).to be(true)
    end
  end
end
