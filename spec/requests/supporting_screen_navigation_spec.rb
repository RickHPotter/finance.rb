# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Supporting screen navigation", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }
  let(:reference) do
    create(
      :reference,
      context: user.main_context,
      user_card:,
      month: 5,
      year: 2026,
      reference_date: Date.new(2026, 5, 10),
      reference_closing_date: Date.new(2026, 5, 3)
    )
  end

  before { sign_in user }

  it "renders top-level supporting entry screens as canonical HTML" do
    [
      contexts_path,
      balances_path(tab: "monthly_analysis", month: "2026-05"),
      donation_static_path,
      edit_user_card_reference_path(user_card, reference),
      merge_user_card_references_path(user_card, id: reference.id)
    ].each do |path|
      get path, headers: html_headers

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq(Mime[:html].to_s)
      expect(response.body).not_to include("<turbo-stream")
    end
  end

  it "canonicalizes obsolete stream-format supporting entry URLs" do
    {
      contexts_path(format: :turbo_stream) => contexts_path,
      balances_path(format: :turbo_stream) => balances_path,
      donation_static_path(format: :turbo_stream) => donation_static_path,
      edit_user_card_reference_path(user_card, reference, format: :turbo_stream) => edit_user_card_reference_path(user_card, reference),
      merge_user_card_references_path(user_card, id: reference.id, format: :turbo_stream) => merge_user_card_references_path(user_card, id: reference.id)
    }.each do |stream_path, canonical_path|
      get stream_path

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(canonical_path)
    end
  end

  it "keeps context show and new responses bounded to their overlay frame" do
    context = create(:context, user:, source_context: user.main_context)

    [
      context_path(context),
      new_context_path(source_context_id: user.main_context.id)
    ].each do |path|
      get path, headers: html_headers.merge("Turbo-Frame" => "context_overlay")

      expect(response).to have_http_status(:success)
      expect(response.body).to include(%[turbo-frame id="context_overlay"])
      expect(response.body).not_to match(/<!doctype|<html/i)
    end
  end

  it "switches context with a validated explicit destination and rejects unsafe destinations" do
    context = create(:context, user:, source_context: user.main_context)
    destination = balances_path(tab: "monthly_analysis", month: "2026-05")

    patch switch_context_path(context), params: { return_to: destination }, headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(destination)
    expect(session[:current_context_id]).to eq(context.id)

    patch switch_context_path(user.main_context), params: { return_to: "https://evil.example/balances" }, headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(root_path)
  end

  it "maps context switches away from context-specific member forms" do
    context = create(:context, user:, source_context: user.main_context)

    patch switch_context_path(context), params: { return_to: edit_user_card_reference_path(user_card, reference) }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(user_cards_path)
  end

  it "updates a reference with 303 and retains the user-card index return state" do
    return_to = Navigation::UserCards.new(
      raw: user_cards_path(search_term: user_card.user_card_name, user_card: { status: [ "active" ] }),
      fallback: user_cards_path,
      current_user: user
    ).destination

    patch user_card_reference_path(user_card, reference), params: {
      return_to:,
      reference: {
        reference_closing_date: Date.new(2026, 5, 4),
        reference_date: Date.new(2026, 5, 11)
      }
    }, headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(edit_user_card_path(user_card, return_to:))
    expect(reference.reload.reference_date).to eq(Date.new(2026, 5, 11))
  end

  it "renders reference validation and merge failures at 422 without changing resources" do
    patch user_card_reference_path(user_card, reference), params: {
      reference: {
        reference_closing_date: Date.new(2026, 5, 4),
        reference_date: ""
      }
    }, headers: turbo_stream_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.media_type).to eq(Mime[:html].to_s)
    expect(response.location).to be_nil

    expect do
      post perform_merge_user_card_references_path(user_card), params: {
        source_reference_date: "2026-05",
        target_reference_date: "2026-07"
      }, headers: turbo_stream_headers
    end.not_to change(Reference, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.media_type).to eq(Mime[:html].to_s)
    expect(response.location).to be_nil
  end

  it "redirects a successful reference merge with 303 to the retained card edit destination" do
    allow(Logic::References).to receive(:merge).and_return(true)
    return_to = user_cards_path(search_term: "visa")

    post perform_merge_user_card_references_path(user_card), params: {
      return_to:,
      source_reference_date: "2026-05",
      target_reference_date: "2026-06"
    }, headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(edit_user_card_path(user_card, return_to:))
  end
end
