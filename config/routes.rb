# frozen_string_literal: true

Rails.application.routes.draw do
  resources :pages do
    collection do
      get 'card_transaction'
      get 'transaction'
      get 'whatever'
    end
  end

  root 'pages#home'
end
