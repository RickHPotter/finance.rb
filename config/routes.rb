# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    confirmations: "users/confirmations"
  }

  resources :pages, only: :index
  resources :user_cards, except: :show
  resources :entities
  resources :categories
  resources :cash_transactions
  resources :card_transactions do
    collection { get :month_year }
  end

  root "pages#index"
end
