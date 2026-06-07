# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UseCase::User::UpdateUserProfileUseCase do
  subject(:use_case) { described_class.new }

  let(:user) { create(:user, name: 'Antiga', phone: '+5511900000000') }

  describe '#call' do
    context 'when name and phone are provided' do
      it 'updates the user attributes' do
        result = use_case.call(user: user, attributes: { name: 'Nova', phone: '+5511911112222' })

        expect(result).to eq(user)
        expect(user.reload).to have_attributes(name: 'Nova', phone: '+5511911112222')
      end
    end

    context 'when only name is provided' do
      it 'updates only the name and keeps the phone untouched' do
        use_case.call(user: user, attributes: { name: 'Apenas Nome' })

        expect(user.reload).to have_attributes(name: 'Apenas Nome', phone: '+5511900000000')
      end
    end

    context 'when attributes use string keys' do
      it 'symbolizes keys and updates the user' do
        use_case.call(user: user, attributes: { 'name' => 'String Key' })

        expect(user.reload.name).to eq('String Key')
      end
    end

    context 'when string attributes have surrounding whitespace' do
      it 'trims the values before persisting' do
        use_case.call(user: user, attributes: { name: '  Trimmed  ', phone: '  +5511933334444  ' })

        expect(user.reload).to have_attributes(name: 'Trimmed', phone: '+5511933334444')
      end
    end

    context 'when attributes contain disallowed keys' do
      it 'ignores them and updates only permitted attributes' do
        original_email = user.email

        use_case.call(user: user, attributes: { name: 'OK', email: 'novo@exemplo.com', password: 'hack' })

        expect(user.reload).to have_attributes(name: 'OK', email: original_email)
      end
    end

    context 'when name is blank' do
      it 'raises ActiveRecord::RecordInvalid' do
        expect {
          use_case.call(user: user, attributes: { name: '' })
        }.to raise_error(ActiveRecord::RecordInvalid, /Name/)
      end
    end

    context 'when no permitted attributes are provided and no avatar action' do
      it 'raises ArgumentError' do
        expect {
          use_case.call(user: user, attributes: { email: 'x@y.com' })
        }.to raise_error(ArgumentError, /No attributes/)
      end
    end

    context 'when attributes is blank and no avatar action' do
      it 'raises ArgumentError' do
        expect {
          use_case.call(user: user, attributes: {})
        }.to raise_error(ArgumentError, /No attributes/)
      end
    end

    context 'when user is nil' do
      it 'raises ArgumentError' do
        expect {
          use_case.call(user: nil, attributes: { name: 'Foo' })
        }.to raise_error(ArgumentError, /User is required/)
      end
    end

    context 'when avatar is provided' do
      let(:avatar_upload) { build_upload(content_type: 'image/png', filename: 'avatar.png', bytes: png_fixture_bytes) }

      it 'attaches the avatar to the user' do
        use_case.call(user: user, attributes: {}, avatar: avatar_upload)

        expect(user.reload.avatar).to be_attached
      end

      it 'allows attaching avatar alongside other attributes' do
        use_case.call(user: user, attributes: { name: 'Com Avatar' }, avatar: avatar_upload)

        expect(user.reload).to have_attributes(name: 'Com Avatar')
        expect(user.avatar).to be_attached
      end
    end

    context 'when avatar content type is not allowed' do
      let(:invalid_upload) { build_upload(content_type: 'application/pdf', filename: 'doc.pdf', bytes: 'PDF') }

      it 'raises ActiveRecord::RecordInvalid and does not persist the avatar' do
        expect {
          use_case.call(user: user, attributes: {}, avatar: invalid_upload)
        }.to raise_error(ActiveRecord::RecordInvalid, /Avatar/)

        expect(user.reload.avatar).not_to be_attached
      end
    end

    context 'when remove_avatar is truthy and an avatar is attached' do
      before do
        user.avatar.attach(
          io: StringIO.new(png_fixture_bytes),
          filename: 'old.png',
          content_type: 'image/png'
        )
      end

      it 'removes the current avatar' do
        use_case.call(user: user, attributes: {}, remove_avatar: '1')

        expect(user.reload.avatar).not_to be_attached
      end
    end
  end

  def build_upload(content_type:, filename:, bytes:)
    file = Tempfile.new(['upload', File.extname(filename)], binmode: true)
    file.binmode
    file.write(bytes)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, content_type, true, original_filename: filename)
  end

  def png_fixture_bytes
    [
      "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06" \
      "\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\xdac\xfc\xcf\xc0\x00\x00\x00" \
      "\x05\x00\x01\x0d\x0a\x2d\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    ].pack('A*')
  end
end
