# frozen_string_literal: true

RSpec.describe EmailToken do
  it { is_expected.to validate_presence_of :user_id }
  it { is_expected.to validate_presence_of :email }
  it { is_expected.to belong_to :user }

  describe '#create' do
    fab!(:user) { Fabricate(:user, active: false) }
    let!(:original_token) { user.email_tokens.first }
    let!(:email_token) { Fabricate(:email_token, user: user, email: 'bubblegum@adventuretime.ooo') }

    it 'should create the email token' do
      expect(email_token).to be_present
    end

    it 'should downcase the email' do
      token = Fabricate(:email_token, user: user, email: "UpperCaseSoWoW@GMail.com")
      expect(token.email).to eq "uppercasesowow@gmail.com"
    end

    it 'is valid' do
      expect(email_token).to be_valid
    end

    it 'has a token' do
      expect(email_token.token).to be_present
    end

    it 'is not confirmed' do
      expect(email_token).to_not be_confirmed
    end

    it 'is not expired' do
      expect(email_token).to_not be_expired
    end

    it 'marks the older token as expired' do
      original_token.reload
      expect(original_token).to be_expired
    end
  end

  describe '#confirm' do
    fab!(:user) { Fabricate(:user, active: false) }
    let!(:email_token) { Fabricate(:email_token, user: user) }

    it 'returns nil with a nil token' do
      expect(EmailToken.confirm(nil)).to be_blank
    end

    it 'returns nil with an invalid token' do
      expect(EmailToken.confirm("random token")).to be_blank
    end

    it 'returns nil when a token is expired' do
      email_token.update_column(:expired, true)
      expect(EmailToken.confirm(email_token.token)).to be_blank
    end

    it 'returns nil when a token is older than a specific time' do
      SiteSetting.email_token_valid_hours = 10
      email_token.update_column(:created_at, 11.hours.ago)
      expect(EmailToken.confirm(email_token.token)).to be_blank
    end

    context 'taken email address' do
      before do
        @other_user = Fabricate(:coding_horror)
        email_token.update_attribute :email, @other_user.email
      end

      it 'returns nil when the email has been taken since the token has been generated' do
        expect(EmailToken.confirm(email_token.token)).to be_blank
      end
    end

    context 'welcome message' do
      it 'sends a welcome message when the user is activated' do
        user = EmailToken.confirm(email_token.token)
        expect(user.send_welcome_message).to eq true
      end

    end

    context 'success' do
      let!(:confirmed_user) { EmailToken.confirm(email_token.token) }

      it "returns the correct user" do
        expect(confirmed_user).to eq user
      end

      it 'marks the user as active' do
        confirmed_user.reload
        expect(confirmed_user).to be_active
      end

      it 'marks the token as confirmed' do
        email_token.reload
        expect(email_token).to be_confirmed
      end

      it "will not confirm again" do
        expect(EmailToken.confirm(email_token.token)).to be_blank
      end
    end

    context 'confirms the token and redeems invite' do
      before do
        SiteSetting.must_approve_users = true
        Jobs.run_immediately!
      end

      fab!(:invite) { Fabricate(:invite, email: 'test@example.com') }
      fab!(:invited_user) { Fabricate(:user, active: false, email: invite.email) }
      let!(:user_email_token) { Fabricate(:email_token, user: invited_user, scope: EmailToken.scopes[:signup]) }
      let!(:confirmed_invited_user) { EmailToken.confirm(user_email_token.token, scope: EmailToken.scopes[:signup]) }

      it "returns the correct user" do
        expect(confirmed_invited_user).to eq invited_user
      end

      it 'marks the user as active' do
        confirmed_invited_user.reload
        expect(confirmed_invited_user).to be_active
      end

      it 'marks the token as confirmed' do
        user_email_token.reload
        expect(user_email_token).to be_confirmed
      end

      it 'redeems invite' do
        invite.reload
        expect(invite).to be_redeemed
      end

      it 'marks the user as approved' do
        expect(confirmed_invited_user).to be_approved
      end
    end

    context 'does not redeem the invite if token is password_reset' do
      before do
        SiteSetting.must_approve_users = true
        Jobs.run_immediately!
      end

      fab!(:invite) { Fabricate(:invite, email: 'test@example.com') }
      fab!(:invited_user) { Fabricate(:user, active: false, email: invite.email) }
      let!(:user_email_token) { Fabricate(:email_token, user: invited_user, scope: EmailToken.scopes[:password_reset]) }
      let!(:confirmed_invited_user) { EmailToken.confirm(user_email_token.token, scope: EmailToken.scopes[:password_reset]) }

      it "returns the correct user" do
        expect(confirmed_invited_user).to eq invited_user
      end

      it 'marks the user as active' do
        confirmed_invited_user.reload
        expect(confirmed_invited_user).to be_active
      end

      it 'marks the token as confirmed' do
        user_email_token.reload
        expect(user_email_token).to be_confirmed
      end

      it 'does not redeem invite' do
        invite.reload
        expect(invite).not_to be_redeemed
      end

      it 'marks the user as approved' do
        expect(confirmed_invited_user).to be_approved
      end
    end
  end
end
