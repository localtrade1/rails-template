# frozen_string_literal: true

require "rails_helper"

# The Console handshake is owned by machina-auth: the engine (mounted at /machina)
# serves the callback and verifies the login state nonce there. These assert the
# app mounts the engine and that a callback without valid state is rejected — the
# login-CSRF / session-fixation guard — setting no session cookie.
RSpec.describe "Authentication" do
  it "renders the sign-in page" do
    get "/login"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sign in")
  end

  it "rejects a callback whose state does not match, setting no session cookie" do
    get "/machina/callback", params: { token: "ps_forged", state: "nope" }

    expect(response).to have_http_status(422)
    expect(response.cookies["machina_session"]).to be_nil
  end
end
