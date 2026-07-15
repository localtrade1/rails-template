# frozen_string_literal: true

class User < ApplicationRecord
  ORG_EMAIL_DOMAIN = "APPNAME_DOMAIN"

  validates :provider, presence: true
  validates :email, presence: true, uniqueness: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :member_ref, uniqueness: true, allow_nil: true

  def self.find_or_create_from_authorized(authorized)
    return nil unless authorized

    member_ref = authorized.user_id
    user = find_by(member_ref: member_ref) if member_ref.present?
    user ||= find_by(email: authorized.user_email) if authorized.user_email.present?

    attrs = {
      email: authorized.user_email,
      name: authorized.user_name,
      avatar_url: authorized.avatar_url,
      member_ref: member_ref
    }

    if user
      user.update!(attrs.compact)
      user
    else
      create!(
        attrs.compact.merge(
          provider: "machina",
          uid: member_ref
        )
      )
    end
  end

  def display_name
    name.presence || email
  end

  def org_member?
    email.to_s.end_with?("@#{ORG_EMAIL_DOMAIN}")
  end
end
