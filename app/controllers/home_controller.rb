# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    landing_page = current_user.preference.landing_page.to_s

    if landing_page == "balance"
      redirect_to balances_path
    elsif landing_page.start_with?("card_transactions_")
      card_id = landing_page.split("_").last
      redirect_to card_transactions_path(user_card_id: card_id)
    else
      redirect_to cash_transactions_path
    end
  end
end
