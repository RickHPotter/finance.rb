require 'rails_helper'

RSpec.describe 'Pages', type: :request do
  describe 'GET /pages' do
    it 'works! (now write some real specs)' do
      get pages_index_path
      expect(response).to have_http_status(200)
    end
  end
end
