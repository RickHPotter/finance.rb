# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users
  resources :pages do
    collection do
      get 'card_transaction'
      get 'transaction'
      get 'whatever'
      get 'whatevers'
    end
  end

  resources :card_transactions
  resources :transactions

  root 'pages#home'
end
