# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Layout and Footer Navigation", type: :request do
  let(:allowed_user) { create(:user, :random, id: 1) }
  let(:regular_user) { create(:user, :random, id: 999) }

  describe "Desktop layout elements" do
    before { sign_in allowed_user }

    it "renders desktop sticky context info, logout button, and donate button" do
      get donation_static_path

      expect(response).to have_http_status(:ok)
      document = response.parsed_body

      # Top navbar section retains its original mt-6 placement
      section = document.at_css("section")
      expect(section["class"]).to include("mt-6")

      # Sticky context at top left (info only, no form or button to change context)
      context_info = document.at_css("#desktop_context_info")
      expect(context_info).to be_present
      expect(context_info["class"]).to include("fixed", "top-4", "left-4")
      expect(context_info.text).to include(allowed_user.main_context.name)
      expect(context_info.at_css("button, form, a")).to be_nil

      # Sticky logout button at top right
      logout = document.at_css("#desktop_logout")
      expect(logout).to be_present
      expect(logout["class"]).to include("fixed", "top-4", "right-4")
      logout_link = logout.at_css("a[href='#{destroy_user_session_path}']")
      expect(logout_link).to be_present
      expect(logout_link["data-turbo-method"]).to eq("delete")

      # Sticky donate link at bottom left
      donate = document.at_css("#desktop_donate")
      expect(donate).to be_present
      expect(donate["class"]).to include("fixed", "bottom-4", "left-4")
      expect(donate.at_css("a[href='#{donation_static_path}']")).to be_present
    end

    it "renders the desktop footer with correct row structure" do
      get donation_static_path

      expect(response).to have_http_status(:ok)
      document = response.parsed_body

      footer = document.at_css("footer")
      expect(footer).to be_present

      desktop_section = footer.at_css("div.hidden.md\\:block")
      expect(desktop_section).to be_present

      # Row 1: theme toggle on left, language buttons on far right
      row1 = desktop_section.at_css("div.flex.items-center.justify-between")
      expect(row1).to be_present
      expect(row1.at_css("button#theme_toggle")).to be_present
      expect(row1.css("form[action*='/locale']").size).to eq(2)

      # Row 2: BabyNames link centered
      row2 = desktop_section.at_css("div.flex.justify-center a[href='#{baby_names_path}']")
      expect(row2).to be_present
    end

    it "does not render baby names link in desktop footer for unauthorized users" do
      sign_out allowed_user
      sign_in regular_user

      get donation_static_path

      expect(response).to have_http_status(:ok)
      document = response.parsed_body

      desktop_section = document.at_css("footer div.hidden.md\\:block")
      expect(desktop_section.at_css("a[href='#{baby_names_path}']")).to be_nil
    end
  end

  describe "Mobile layout elements" do
    before { sign_in allowed_user }

    it "renders the 4 mobile rows in correct order" do
      get donation_static_path

      expect(response).to have_http_status(:ok)
      document = response.parsed_body

      mobile_section = document.at_css("footer div.block.md\\:hidden")
      expect(mobile_section).to be_present

      rows = mobile_section.element_children
      expect(rows.size).to eq(4)

      # Row 1: spreaded, Donate, Baby Names, Logout
      row1 = rows[0]
      expect(row1["class"]).to include("justify-between")
      expect(row1.at_css("a[href='#{donation_static_path}']")).to be_present
      expect(row1.at_css("a[href='#{baby_names_path}']")).to be_present
      expect(row1.at_css("a[href='#{destroy_user_session_path}']")).to be_present

      # Row 2: centered light dark button
      row2 = rows[1]
      expect(row2["class"]).to include("justify-center")
      expect(row2.at_css("button#theme_toggle_mobile")).to be_present

      # Row 3: centered language buttons
      row3 = rows[2]
      expect(row3["class"]).to include("justify-center")
      expect(row3.css("form[action*='/locale']").size).to eq(2)

      # Row 4: centered context info (info only, no button)
      row4 = rows[3]
      expect(row4["class"]).to include("justify-center")
      expect(row4.text).to include(allowed_user.main_context.name)
      expect(row4.at_css("button, form, a")).to be_nil
    end

    it "does not render baby names link in mobile row 1 for unauthorized users" do
      sign_out allowed_user
      sign_in regular_user

      get donation_static_path

      expect(response).to have_http_status(:ok)
      document = response.parsed_body

      mobile_section = document.at_css("footer div.block.md\\:hidden")
      row1 = mobile_section.element_children[0]
      expect(row1.at_css("a[href='#{baby_names_path}']")).to be_nil
      expect(row1.at_css("a[href='#{donation_static_path}']")).to be_present
      expect(row1.at_css("a[href='#{destroy_user_session_path}']")).to be_present
    end
  end
end
