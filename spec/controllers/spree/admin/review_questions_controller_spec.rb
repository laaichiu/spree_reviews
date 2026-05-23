require 'spec_helper'

RSpec.describe Spree::Admin::ReviewQuestionsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store], name: 'Everyday Tee') }

  describe 'GET #index' do
    let!(:second_question) { create(:review_question, store: store, label: 'Overall fit', position: 2) }
    let!(:first_question) { create(:review_question, store: store, label: 'Body type', position: 1) }

    it 'renders current-store questions in configured order' do
      create(:review_question, store: create(:store), label: 'Other store question')

      get :index

      expect(response).to be_successful
      expect(response.body).to match(%r{<title>\s*Review Questions\s*-\s*[^<]+</title>})
      expect(response.body).not_to include('Hello SpreeReviews')
      expect(assigns(:collection)).to eq([first_question, second_question])
      expect(response.body).to include('Body type')
      expect(response.body).to include('Overall fit')
      expect(response.body).not_to include('Other store question')
    end
  end

  describe 'GET #new' do
    it 'renders the question form' do
      product

      get :new

      expect(response).to be_successful
      expect(response.body).to match(%r{<title>\s*New Review Question\s*-\s*Review Questions\s*-\s*[^<]+</title>})
      expect(response.body).to include('New review question')
      expect(response.body).to include('Everyday Tee')
      expect(response.body).to include('Settings')
      expect(response.body).to match(%r{<label[^>]+for="review_question_required"[^>]*>\s*Required\s*</label>})
      expect(response.body).to include('data-controller="spree-reviews-slug-field"')
      expect(response.body).to include("import 'application-spree-reviews'")
      expect(response.body).to match(%r{<th>\s*Label\s*</th>\s*<th>\s*Value\s*</th>})
      expect(response.body).to include('Answer options')
    end

    it 'renders category options with hierarchy and descendant product counts' do
      taxonomy = create(:taxonomy, store: store)
      parent_taxon = create(:taxon, taxonomy: taxonomy, name: 'Clothing')
      child_taxon = create(:taxon, taxonomy: taxonomy, parent: parent_taxon, name: 'Dresses')
      product.taxons << child_taxon

      get :new

      expect(response).to be_successful
      expect(response.body).to include('Clothing &gt; Dresses (1 product)')
      expect(response.body).to include('Category-scoped questions apply to the selected category and all descendant categories.')
    end
  end

  describe 'POST #create' do
    it 'creates a product-scoped question with answer options' do
      expect {
        post :create,
             params: {
               review_question: {
                 key: 'overall_fit',
                 label: 'Overall fit',
                 kind: 'single_select',
                 applies_to: 'product',
                 product_id: product.id,
                 filterable: true,
                 required: true,
                 active: true,
                 position: 3,
                 options_attributes: {
                   '0' => { value: 'true_to_size', label: 'True to size', position: 1, active: true },
                   '1' => { value: 'runs_small', label: 'Runs small', position: 2, active: true }
                 }
               }
             }
      }.to change(Spree::ReviewQuestion, :count).by(1)
       .and change(Spree::ReviewQuestionOption, :count).by(2)

      question = Spree::ReviewQuestion.last
      expect(question.store).to eq(store)
      expect(question.product).to eq(product)
      expect(question.options.map(&:value)).to contain_exactly('true_to_size', 'runs_small')
      expect(response).to redirect_to(edit_admin_review_question_path(question))
    end
  end

  describe 'GET #edit' do
    it 'renders existing question options' do
      question = create(:review_question, store: store, label: 'Body type')
      create(:review_question_option, question: question, value: 'curvy_on_top', label: 'Curvy on top')

      get :edit, params: { id: question.to_param }

      expect(response).to be_successful
      expect(response.body).to match(%r{<title>\s*Body type\s*-\s*Review Questions\s*-\s*[^<]+</title>})
      expect(response.body).to include('Body type')
      expect(response.body).to include('curvy_on_top')
      expect(response.body).to include('Curvy on top')
    end

    it 'previews matched products for the selected category and descendants' do
      taxonomy = create(:taxonomy, store: store)
      parent_taxon = create(:taxon, taxonomy: taxonomy, name: 'Clothing')
      child_taxon = create(:taxon, taxonomy: taxonomy, parent: parent_taxon, name: 'Dresses')
      product.taxons << child_taxon
      question = create(:review_question, :for_category, store: store, category: parent_taxon, label: 'Overall fit')

      get :edit, params: { id: question.to_param }

      expect(response).to be_successful
      expect(response.body).to include('Current category matches 1 product')
      expect(response.body).to include('including products in descendant categories')
    end
  end

  describe 'PUT #update' do
    it 'updates question fields and nested options' do
      question = create(:review_question, store: store, key: 'body_type', label: 'Body type')
      option = create(:review_question_option, question: question, value: 'curvy_on_top', label: 'Curvy on top')

      put :update,
          params: {
            id: question.to_param,
            review_question: {
              label: 'Body shape',
              required: true,
              options_attributes: {
                '0' => { id: option.id, value: 'curvy_on_top', label: 'Curvy on top updated', position: 2, active: true },
                '1' => { value: 'straight', label: 'Straight', position: 1, active: true }
              }
            }
          }

      expect(question.reload).to have_attributes(label: 'Body shape', required: true)
      expect(option.reload).to have_attributes(label: 'Curvy on top updated', position: 2)
      expect(question.options.map(&:value)).to contain_exactly('curvy_on_top', 'straight')
      expect(response).to redirect_to(edit_admin_review_question_path(question))
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes a question and its options' do
      question = create(:review_question, store: store)
      create(:review_question_option, question: question)

      expect {
        delete :destroy, params: { id: question.to_param }
      }.to change(Spree::ReviewQuestion, :count).by(-1)
       .and change(Spree::ReviewQuestionOption, :count).by(-1)

      expect(response).to redirect_to(admin_review_questions_path)
    end
  end
end
