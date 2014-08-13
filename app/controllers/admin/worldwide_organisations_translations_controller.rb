class Admin::WorldwideOrganisationsTranslationsController < Admin::BaseController
  include Admin::TranslationsControllerConcerns

  before_filter :load_worldwide_organisation
  before_filter :load_translated_and_english_worldwide_organisations, except: [:index]
  helper_method :translation_locale

  def index
  end

  def update
    if @translated_worldwide_organisation.update_attributes(worldwide_organisation_params)
      redirect_to admin_worldwide_organisation_translations_path(@translated_worldwide_organisation),
        notice: notice_message("saved")
    else
      render action: 'edit'
    end
  end

  def destroy
    @translated_worldwide_organisation.remove_translations_for(translation_locale.code)
    redirect_to admin_worldwide_organisation_translations_path(@translated_worldwide_organisation),
      notice: notice_message("deleted")
  end

  private

  def create_redirect_path
    edit_admin_worldwide_organisation_translation_path(@worldwide_organisation, id: translation_locale)
  end

  def notice_message(action)
    %{#{translation_locale.english_language_name} translation for "#{@worldwide_organisation.name}" #{action}.}
  end

  def load_translated_and_english_worldwide_organisations
    @translated_worldwide_organisation = LocalisedModel.new(@worldwide_organisation, translation_locale.code)
    @english_worldwide_organisation = LocalisedModel.new(@worldwide_organisation, :en)
  end

  def translation_locale
    @translation_locale ||= Locale.new(params[:translation_locale] || params[:id])
  end

  def load_worldwide_organisation
    @worldwide_organisation ||= WorldwideOrganisation.find(params[:worldwide_organisation_id])
  end

  def worldwide_organisation_params
    params.require(:worldwide_organisation).permit(
      :name, :summary, :description, :services
    )
  end
end
