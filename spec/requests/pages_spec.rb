# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pages#Home', type: :request do
  describe 'GET /' do
    context 'when not logged in' do
      it 'redirects to sign-in page' do
        get '/'

        expect(response).to have_http_status(:redirect)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
