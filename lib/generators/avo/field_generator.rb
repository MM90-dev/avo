require 'yaml'

class FieldGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates/field', __dir__)

  namespace 'avo:field'
  desc 'Create stubs for a new field.'
  class_option :name, type: :string
  class_option :force, type: :boolean

  def create_files
    field_path = Rails.root.join 'app', 'services', 'avocado', 'fields', singular_name

    begin
      webpacker_fields = Dir.glob("#{Rails.root}/**/webpacker.yml")
      webpack_ports = webpacker_fields.map { |file| YAML.load(File.read(file))['development']['dev_server']['port'] }
      @next_webpacker_port = webpack_ports.sort.last + 1
    rescue
      @next_webpacker_port = 3045
    end

    directory 'raw', field_path

    chmod "#{field_path}/bin/webpack", 0755
    chmod "#{field_path}/bin/webpack-dev-server", 0755

    template 'template_field.rb', "#{field_path}/#{singular_name}_field.rb"
    template 'tool_provider.rb', "#{field_path}/tool_provider.rb"
    template 'package.json', "#{field_path}/package.json"
    template 'webpacker.yml', "#{field_path}/config/webpacker.yml"
    template 'field.js', "#{field_path}/frontend/packs/#{singular_name}_field.js"

    package_json_file = JSON.parse(File.read(Rails.root.join('package.json')))
    package_json_file['scripts'] ||= {}
    package_json_file['scripts']["build-#{name}-field"] = "cd #{field_path.sub("#{Rails.root.to_s}/", '')} && bin/webpack"
    package_json_file['scripts']["dev-#{name}-field"] = "cd #{field_path.sub("#{Rails.root.to_s}/", '')} && bin/webpack-dev-server"
    File.open(Rails.root.join('package.json'), 'w') { |file| file.write("#{JSON.pretty_generate(package_json_file)}\n") }
    say_status :update, "#{field_path}/package.json"

    if options[:force] || yes?('Do you want to run `yarn install` and `bundle install` now? y/n', :cyan)
      inside field_path do
        run 'yarn install'
        run 'bundle install'
      end
    end

    if options[:force] || yes?('Do you want to do an initial compilation for your new assets? y/n', :cyan)
      inside Pathname.new(field_path).join('bin') do
        run_ruby_script 'webpack'
      end
    end

    say "We generated you new field files under #{field_path}. You may edit the component files.", :green
  end
end
