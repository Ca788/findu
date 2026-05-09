# frozen_string_literal: true

require "rails_helper"

RSpec.describe Artifact do
  let(:user) { create(:user) }

  describe "validations" do
    it "is invalid without artifact_type" do
      artifact = build(:artifact, user: user, artifact_type: nil)

      expect(artifact).not_to be_valid
      expect(artifact.errors[:artifact_type]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to a user" do
      artifact = create(:artifact, user: user)

      expect(artifact.user).to eq(user)
    end
  end

  describe "destroy" do
    let!(:artifact) { create(:artifact, user: user) }

    context "when artifact has an attached file" do
      before do
        artifact.file.attach(
          io: StringIO.new("fake content"),
          filename: "receipt.png",
          content_type: "image/png"
        )
      end

      it "purges the attached file via dependent: :purge_later" do
        expect { artifact.destroy! }
          .to change(ActiveStorage::Attachment, :count).by(-1)
      end
    end

    context "when artifact has an associated financial_transaction" do
      let!(:transaction) do
        create(:financial_transaction, user: user, artifact: artifact)
      end

      it "destroys the associated financial_transaction" do
        expect { artifact.destroy! }
          .to change(Financial::Transaction, :count).by(-1)
      end

      it "removes the specific transaction record" do
        artifact.destroy!

        expect(Financial::Transaction.find_by(id: transaction.id)).to be_nil
      end
    end

    context "when artifact has neither file nor transaction" do
      it "destroys cleanly" do
        expect { artifact.destroy! }
          .to change(described_class, :count).by(-1)
      end
    end
  end
end
