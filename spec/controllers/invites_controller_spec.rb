# frozen_string_literal: true

require 'spec_helper'

RSpec.describe InvitesController, :snowplow do
  let_it_be(:user) { create(:user) }
  let(:member) { create(:project_member, :invited, invite_email: user.email) }
  let(:raw_invite_token) { member.raw_invite_token }
  let(:project_members) { member.source.users }
  let(:md5_member_global_id) { Digest::MD5.hexdigest(member.to_global_id.to_s) }
  let(:params) { { id: raw_invite_token } }
  let(:snowplow_event) do
    {
      category: 'Growth::Acquisition::Experiment::InviteEmail',
      label: md5_member_global_id,
      property: group_type
    }
  end

  before do
    controller.instance_variable_set(:@member, member)
  end

  describe 'GET #show' do
    subject(:request) { get :show, params: params }

    context 'when logged in' do
      before do
        sign_in(user)
      end

      it 'accepts user if invite email matches signed in user' do
        expect do
          request
        end.to change { project_members.include?(user) }.from(false).to(true)

        expect(response).to have_gitlab_http_status(:found)
        expect(flash[:notice]).to include 'You have been granted'
      end

      it 'forces re-confirmation if email does not match signed in user' do
        member.invite_email = 'bogus@email.com'

        expect do
          request
        end.not_to change { project_members.include?(user) }

        expect(response).to have_gitlab_http_status(:ok)
        expect(flash[:notice]).to be_nil
      end

      context 'when new_user_invite is not set' do
        it 'does not track the user as experiment group' do
          request

          expect_no_snowplow_event
        end
      end

      context 'when new_user_invite is experiment' do
        let(:params) { { id: raw_invite_token, new_user_invite: 'experiment' } }
        let(:group_type) { 'experiment_group' }

        it 'tracks the user as experiment group' do
          request

          expect_snowplow_event(snowplow_event.merge(action: 'opened'))
          expect_snowplow_event(snowplow_event.merge(action: 'accepted'))
        end
      end

      context 'when new_user_invite is control' do
        let(:params) { { id: raw_invite_token, new_user_invite: 'control' } }
        let(:group_type) { 'control_group' }

        it 'tracks the user as control group' do
          request

          expect_snowplow_event(snowplow_event.merge(action: 'opened'))
          expect_snowplow_event(snowplow_event.merge(action: 'accepted'))
        end
      end
    end

    context 'when not logged in' do
      context 'when inviter is a member' do
        it 'is redirected to a new session with invite email param' do
          request

          expect(response).to redirect_to(new_user_session_path(invite_email: member.invite_email))
        end
      end

      context 'when inviter is not a member' do
        let(:params) { { id: '_bogus_token_' } }

        it 'is redirected to a new session' do
          request

          expect(response).to redirect_to(new_user_session_path)
        end
      end
    end
  end

  describe 'POST #accept' do
    before do
      sign_in(user)
    end

    subject(:request) { post :accept, params: params }

    context 'when new_user_invite is not set' do
      it 'does not track an event' do
        request

        expect_no_snowplow_event
      end
    end

    context 'when new_user_invite is experiment' do
      let(:params) { { id: raw_invite_token, new_user_invite: 'experiment' } }
      let(:group_type) { 'experiment_group' }

      it 'tracks the user as experiment group' do
        request

        expect_snowplow_event(snowplow_event.merge(action: 'accepted'))
      end
    end

    context 'when new_user_invite is control' do
      let(:params) { { id: raw_invite_token, new_user_invite: 'control' } }
      let(:group_type) { 'control_group' }

      it 'tracks the user as control group' do
        request

        expect_snowplow_event(snowplow_event.merge(action: 'accepted'))
      end
    end
  end
end
