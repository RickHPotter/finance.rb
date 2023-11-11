# frozen_string_literal: true

Rails.application.routes.draw do
  resources :card_transactions
  # TODO: test without the /
  get '/notice', to: 'card_transactions#clear_message'

  root 'card_transactions#index'
end
