# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    confirmations: "users/confirmations"
  }

  resources :pages, only: :index
  resources :user_cards
  resources :entities
  resources :categories
  resources :cash_transactions
  resources :card_transactions

  root "pages#index"
end
