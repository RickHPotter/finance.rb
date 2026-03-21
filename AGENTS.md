# Repository Guidelines

## Project Structure & Module Organization
This is a Rails 8.1 app for personal finance workflows. The stack combines Rails, PostgreSQL, Hotwire (`Turbo` + `Stimulus`), Phlex, Tailwind CSS, and custom `ruby_ui` components. Core code lives in `app/`: domain models, controllers, jobs, services, components, Phlex/Ruby views, Stimulus controllers, and assets. Configuration is under `config/`, schema and migrations are in `db/`, and reusable rake tasks are in `lib/tasks/`. Tests are RSpec-based in `spec/`, organized by type such as `spec/models`, `spec/requests`, `spec/features`, `spec/services`, and `spec/factories`.

## Build, Test, and Development Commands
Use the project binstubs instead of global commands.

- `bin/setup` installs gems, prepares the database, and clears logs/tmp.
- `bin/dev` starts the local stack from `Procfile.dev` (`rails` on port `3016`, Tailwind watcher, esbuild watcher).
- `bin/rails db:prepare` syncs the local database.
- `bin/rspec` runs the full spec suite; target a folder with `bin/rspec spec/models`.
- Before running `bin/rspec`, load environment variables from `.env.test`; if that file does not exist, load `.env` instead.
- Run `bin/rspec` with elevated permissions so it can connect to the local PostgreSQL test database from this environment.
- `bin/rubocop -A` autocorrects Ruby style issues; run it after each batch of edits before moving on.
- `bin/ci` runs the local CI sequence: setup, RuboCop, ERB lint, RSpec, Bundler Audit, and Brakeman.
- `yarn build` bundles JavaScript into `app/assets/builds`.

## Coding Style, UI Stack & Naming Conventions
Ruby uses 2-space indentation and double-quoted strings by default. Follow `.rubocop.yml`: max line length `166`, keep methods reasonably small, and prefer existing service/component patterns over ad hoc helpers. Name classes by domain (`RecalculateBalanceJob`, `DuePaymentsNotifier`) and keep spec filenames aligned with the class or feature under test, for example `spec/models/user_spec.rb`.

Prefer string-backed enums over integer-backed enums. For example, use `enum :transaction_type, { cash: "cash", card: "card" }` instead of `enum :transaction_type, { cash: 0, card: 1 }`.

Keep model files organized with the repository's section-comment layout, as seen in `app/models/budget_category.rb`: `# @extends`, `# @includes`, `# @relationships`, `# @validations`, and the remaining delimiter blocks should be present even when a section is empty.

For UI work, prefer Phlex/Ruby views and existing components before introducing new ERB partials. Keep interactive flows in Hotwire: use Turbo responses for partial page updates and Stimulus controllers in `app/javascript/controllers/*_controller.js` for client-side behavior. Put reusable UI in `app/components/` and reusable specific views/partials in `app/views/shared/` or their dedicated folder like `app/views/transactions/`, and keep Tailwind utility usage consistent with nearby code instead of mixing in custom one-off CSS unless the style is shared.
In Phlex `.rb` views, call RubyUI components and local `app/components` components directly, for example `Button(...)` or `ModalShell(...)`. Do not write `render RubyUI::Button.new(...)`, `render Components::X.new(...)`, or similar constructor-based calls for components in Phlex files. This rule does not apply to `.html.erb` templates.

In Phlex views, custom helper methods are not available automatically. If a view calls a helper method such as `model_attribute`, its helper module must be explicitly included in that Phlex class, for example `include TranslateHelper`.
The same applies to component/helper methods such as `cached_icon`: include the owning helper module explicitly, for example `include CacheHelper`, instead of assuming it is available.
In Phlex views, do not pass the return value of `options_for_select` as an argument to another helper. `options_for_select` writes HTML directly, so either call it inside the `select` block or pass the raw options collection to the `select` helper and skip `options_for_select` entirely.

When using translation helpers such as `action_message(...)`, verify the locale key already exists before using it. If it does not exist, either add the locale entry first or use an existing translation key instead of assuming the helper call is valid.

## Testing Guidelines
RSpec is the test framework, with FactoryBot, Capybara, and SimpleCov enabled through `spec/rails_helper.rb`. Add specs beside the relevant layer and prefer request/model/service coverage for logic changes; use feature specs for user flows. Run focused checks before pushing, for example `bin/rspec spec/requests spec/models`. CI currently runs `spec/models`, `spec/concerns`, and `spec/requests`, so avoid merging untested changes outside those paths.

## Commit & Pull Request Guidelines
Recent history uses short conventional prefixes such as `feat:`, `style:`, `docs:`, `cleanup:`, `perf:`, and `app:`. Keep commit messages imperative and scoped to one change. Pull requests should include a short summary, note schema or env changes, link the issue when applicable, and include screenshots or recordings for UI/Hotwire updates. Before opening a PR, run `bin/ci`.
