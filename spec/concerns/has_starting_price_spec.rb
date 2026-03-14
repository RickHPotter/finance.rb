# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasStartingPrice, type: :concern do
  describe "[ concern behaviour ]" do
    it "defaults starting_price from price on create" do
      exchange = build(:exchange, price: 123, starting_price: nil)

      exchange.save!

      expect(exchange.starting_price).to eq(123)
    end

    it "does not overwrite a pre-filled starting_price" do
      exchange = build(:exchange, price: 123, starting_price: 456)

      exchange.save!

      expect(exchange.starting_price).to eq(456)
    end
  end
end
