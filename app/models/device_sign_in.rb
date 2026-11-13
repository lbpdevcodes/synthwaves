# A TV that can't type a password asks for one of these, shows its code, and
# checks in with its secret until someone signed in on the web enters the code
# at /link. Only the secret's digest is stored, so the table can't sign anyone in.
class DeviceSignIn < ApplicationRecord
  LIFETIME = 10.minutes
  CHECK_IN_INTERVAL = 5.seconds
  # No vowels, so a code never spells a word, and no 0, O, 1 or I to confuse.
  CODE_CHARACTERS = "BCDFGHJKLMNPQRSTVWXZ23456789".chars.freeze
  CODE_LENGTH = 8

  belongs_to :user, optional: true

  # People type codes in any case, with or without the dash.
  normalizes :code, with: ->(code) { code.upcase.delete("^A-Z0-9") }
  # The device names itself, and the name goes on the /link button.
  normalizes :device_name, with: ->(name) { name.squish.first(40).presence || "TV" }

  scope :live, -> { where(expires_at: Time.current..) }
  scope :pending, -> { live.where(user_id: nil) }
  scope :expired, -> { where(expires_at: ...Time.current) }

  # Only a sign-in just started knows its secret.
  attr_reader :secret

  def self.start(device_name:)
    expired.delete_all
    create!(device_name:, code: new_code, secret: SecureRandom.urlsafe_base64(32), expires_at: LIFETIME.from_now)
  end

  def self.digest(secret)
    OpenSSL::Digest::SHA256.hexdigest(secret)
  end

  def self.find_pending(code)
    pending.find_by(code: code.to_s)
  end

  def self.find_by_secret(secret)
    live.find_by(secret_digest: digest(secret)) if secret.present?
  end

  def self.new_code
    Array.new(CODE_LENGTH) { CODE_CHARACTERS.sample(random: SecureRandom) }.join
  end
  private_class_method :new_code

  def secret=(secret)
    @secret = secret
    self.secret_digest = self.class.digest(secret)
  end

  # Approves only a sign-in still waiting, so two people entering one code
  # can't both sign the TV in.
  def approve(user)
    self.class.pending.where(id:).update_all(user_id: user.id, updated_at: Time.current) == 1
  end

  def pending?
    user_id.nil?
  end

  # Deletes the sign-in as it hands over the user, so only one check-in gets them.
  def claim
    user if self.class.where(id:).where.not(user_id: nil).delete_all == 1
  end

  def display_code
    code.scan(/.{4}/).join("-")
  end
end
