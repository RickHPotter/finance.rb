# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    confirmations: "users/confirmations"
  }

  resources :pages do
    collection do
      get "card_transaction"
      get "transaction"
    end
  end

  resources :card_transactions
  resources :transactions

  root "pages#home"
end
