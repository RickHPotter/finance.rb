# frozen_string_literal: true

module NavigationFeatureHelper
  def expect_browser_path(path)
    expect(page).to have_current_path(path, ignore_query: false)
  end

  def browser_back_to(path)
    page.go_back
    expect_browser_path(path)
  end

  def browser_forward_to(path)
    page.go_forward
    expect_browser_path(path)
  end

  def refresh_browser_at(path)
    page.refresh
    expect_browser_path(path)
  end

  def expect_workflow_finishing_submitter(selector)
    expect(page).to have_css("#{selector}[data-turbo-frame='_top'][data-turbo-action='replace']")
  end

  def expect_local_reactive_submitter(selector)
    submitter = find(selector, visible: :all)

    expect(submitter["data-turbo-frame"]).not_to eq("_top")
    expect(submitter["data-turbo-action"]).not_to eq("replace")
  end
end

RSpec.configure do |config|
  config.include NavigationFeatureHelper, type: :feature
end
