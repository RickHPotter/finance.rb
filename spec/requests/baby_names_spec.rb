# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Baby names", type: :request do
  let(:user) { create(:user, id: 1) }
  let!(:first_name) { create(:baby_name, name: "Arthur", position: 1) }
  let!(:second_name) { create(:baby_name, name: "Theo", position: 2) }

  describe "GET /baby_names" do
    it "requires authentication" do
      get baby_names_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects users that are not Gigi or Rikki (IDs 1 and 4)" do
      unauthorized_user = create(:user, :different, id: 2)
      sign_in unauthorized_user

      get baby_names_path

      expect(response).to redirect_to(root_path)
    end

    it "shows the next name and the user's counts without story prompt or couple header" do
      sign_in user
      create(:baby_name_decision, user:, baby_name: second_name, choice: "accepted")

      get baby_names_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Arthur", "0 / 1", "1 of 2 decided")
      expect(response.body).not_to include(">Theo<")
      expect(response.body).not_to include("Could this be the name at the start of every story?")
      expect(response.body).not_to include("Gigi &amp; Rikki")
    end

    it "shows postponed names again after all unseen names are handled" do
      sign_in user
      create(:baby_name_decision, user:, baby_name: first_name, choice: "later")
      create(:baby_name_decision, user:, baby_name: second_name, choice: "rejected")

      get baby_names_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Arthur", "1 of 2 decided", "1 for later")
      expect(response.body).not_to include("That’s every name.")
    end

    it "uses the authenticated user's locale" do
      sign_in user
      user.profile.update!(locale: "pt-BR")

      get baby_names_path

      expect(response.body).to include("Como vamos chamar você?", "0 de 2 decididos", "Decidir depois")
      expect(response.body).not_to include("What will we call you?")
    end

    it "does not include another user's decisions in the queue or totals" do
      other_user = create(:user, :different, id: 4)
      create(:baby_name_decision, user: other_user, baby_name: first_name, choice: "accepted")
      sign_in user

      get baby_names_path

      expect(response.body).to include("Arthur", "0 / 0", "0 of 2 decided")
    end

    it "cycles a repeatedly postponed name behind the other postponed names" do
      sign_in user
      first_decision = create(:baby_name_decision, user:, baby_name: first_name, choice: "later", updated_at: 2.minutes.ago)
      create(:baby_name_decision, user:, baby_name: second_name, choice: "later", updated_at: 1.minute.ago)

      post baby_name_decision_path(first_name), params: { choice: "later" }
      get baby_names_path

      expect(first_decision.reload.updated_at).to be_within(2.seconds).of(Time.current)
      expect(response.body).to include("Theo")
      expect(response.body).not_to include(">Arthur<")
    end
  end

  describe "POST /baby_names/:baby_name_id/decision" do
    it "redirects users that are not Gigi or Rikki (IDs 1 and 4)" do
      unauthorized_user = create(:user, :different, id: 2)
      sign_in unauthorized_user

      post baby_name_decision_path(first_name), params: { choice: "accepted" }

      expect(response).to redirect_to(root_path)
    end

    context "when signed in as an authorized user" do
      before { sign_in user }

      it "persists the signed-in user's choice" do
        expect do
          post baby_name_decision_path(first_name), params: { choice: "accepted" }
        end.to change(user.baby_name_decisions, :count).by(1)

        expect(response).to redirect_to(baby_names_path)
        expect(user.baby_name_decisions.last).to be_accepted
      end

      it "does not replace an existing choice on a repeated submission" do
        create(:baby_name_decision, user:, baby_name: first_name, choice: "rejected")

        post baby_name_decision_path(first_name), params: { choice: "accepted" }

        expect(response).to redirect_to(baby_names_path)
        expect(user.baby_name_decisions.find_by(baby_name: first_name)).to be_rejected
      end

      it "allows a postponed name to receive a final choice" do
        create(:baby_name_decision, user:, baby_name: first_name, choice: "later")

        post baby_name_decision_path(first_name), params: { choice: "accepted" }

        expect(response).to redirect_to(baby_names_path)
        expect(user.baby_name_decisions.find_by(baby_name: first_name)).to be_accepted
      end

      it "rejects an invalid choice" do
        expect do
          post baby_name_decision_path(first_name), params: { choice: "maybe" }
        end.not_to change(BabyNameDecision, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "allows changing an existing decision when return_to is review" do
        create(:baby_name_decision, user:, baby_name: first_name, choice: "rejected")

        post baby_name_decision_path(first_name), params: { choice: "accepted", return_to: "review", filter: "accepted" }

        expect(response).to redirect_to(review_baby_names_path(filter: "accepted"))
        expect(user.baby_name_decisions.find_by(baby_name: first_name)).to be_accepted
      end
    end
  end

  describe "GET /baby_names/review" do
    it "requires authentication" do
      get review_baby_names_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects unauthorized users" do
      unauthorized_user = create(:user, :different, id: 2)
      sign_in unauthorized_user

      get review_baby_names_path

      expect(response).to redirect_to(root_path)
    end

    it "displays names and their statuses in display order" do
      sign_in user
      create(:baby_name_decision, user:, baby_name: first_name, choice: "accepted")

      get review_baby_names_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Arthur", "Theo")
    end

    it "filters names by choice" do
      sign_in user
      create(:baby_name_decision, user:, baby_name: first_name, choice: "accepted")
      create(:baby_name_decision, user:, baby_name: second_name, choice: "rejected")

      get review_baby_names_path(filter: "accepted")

      expect(response.body).to include("Arthur")
      expect(response.body).not_to include("Theo")
    end
  end

  describe "Phase synchronization & finished state" do
    let!(:partner) { create(:user, :different, id: 4) }

    it "shows waiting for partner when user finished but partner has not" do
      sign_in user
      create(:baby_name_decision, user:, baby_name: first_name, choice: "accepted")
      create(:baby_name_decision, user:, baby_name: second_name, choice: "rejected")

      get baby_names_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Waiting for your partner to finish")
    end

    it "shows start phase 2 CTA when both users finish phase 1" do
      sign_in user
      [ first_name, second_name ].each do |bn|
        create(:baby_name_decision, user:, baby_name: bn, choice: "accepted")
        create(:baby_name_decision, user: partner, baby_name: bn, choice: "accepted")
      end

      get baby_names_path

      # Both done triggers transition to phase 2, redirecting to rank
      expect(response).to redirect_to(rank_baby_names_path)
    end
  end

  describe "GET /baby_names/rank" do
    it "redirects to baby_names_path if user is still in phase 1" do
      sign_in user

      get rank_baby_names_path

      expect(response).to redirect_to(baby_names_path)
    end

    it "renders the ranking interface when user is in phase 2" do
      sign_in user
      BabyNameProcessState.for(user).update!(phase: "phase2", phase_completed: false)
      create(:baby_name_decision, user:, baby_name: first_name, choice: "accepted")

      get rank_baby_names_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Arthur", "Save &amp; Submit Ranking")
    end
  end

  describe "POST /baby_names/rank" do
    it "submits user ranking for phase 2" do
      sign_in user
      BabyNameProcessState.for(user).update!(phase: "phase2", phase_completed: false)
      create(:baby_name_decision, user:, baby_name: first_name, choice: "accepted")
      create(:baby_name_decision, user:, baby_name: second_name, choice: "accepted")

      post rank_baby_names_path, params: { name_ids: [ second_name.id, first_name.id ] }

      expect(response).to redirect_to(rank_baby_names_path)
      expect(user.baby_name_decisions.find_by(baby_name: second_name).position).to eq(1)
      expect(user.baby_name_decisions.find_by(baby_name: first_name).position).to eq(2)
      expect(BabyNameProcessState.for(user).reload.phase_completed?).to be(true)
    end
  end
end
