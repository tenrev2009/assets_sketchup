# File: components/extractor.rb
require 'fileutils'

module ACA::Extractor
  extend self

  def run(extract_components, extract_textures, extract_groups, extract_environments, output_path)
    @output = output_path
    FileUtils.mkdir_p(File.join(@output, 'Components'))
    FileUtils.mkdir_p(File.join(@output, 'Textures'))
    FileUtils.mkdir_p(File.join(@output, 'Environments')) if extract_environments

    model = Sketchup.active_model
    
    # Récupération de toutes les définitions pour un scan profond
    all_defs = model.definitions

    if extract_components
      comps = all_defs.reject { |d| d.group? || d.image? || d.internal? }
      export_definitions(comps, 'Components', '.skp')
    end

    if extract_groups
      grps = all_defs.select { |d| d.group? && !d.internal? }
      export_definitions(grps, 'Components', '.skp', 'Group')
    end

    if extract_textures
      export_all_textures(model, all_defs)
    end

    if extract_environments
      export_environments(model)
    end
  end

  # ... (méthodes export_definitions et export_all_textures identiques à ma réponse précédente) ...
  # (Je ne les répète pas ici pour faire court, mais garde bien la version "Deep Scan" fournie précédemment)

  def export_definitions(definitions, subdir, ext, prefix_fallback='Component')
     # ... voir code précédent ...
     definitions.each_with_index do |defn, idx|
      real_name = defn.name.to_s.strip
      base = real_name.empty? ? "#{prefix_fallback}_#{idx}" : real_name
      safe = base.gsub(/[\/\\:\*\?"<>\|]/, '_')
      dest = unique_path(safe, subdir, ext)
      begin
        defn.save_as(dest)
      rescue => e; end
    end
  end
  
  def export_all_textures(model, all_defs)
     # ... voir code précédent (logique image_rep) ...
     # Utilise le code de ma réponse précédente pour cette partie
  end

  # Nouvelle méthode pour les environnements
  def export_environments(model)
    # Vérification de compatibilité (SketchUp 2024+)
    return unless model.respond_to?(:environments)

    model.environments.each_with_index do |env, idx|
      begin
        name = env.name.to_s.strip
        name = "Environment_#{idx}" if name.empty?
        safe_name = name.gsub(/[\/\\:\*\?"<>\|]/, '_')

        # Tentative de récupération de la texture
        # L'API Environment est récente, on cherche la texture sous-jacente
        texture = env.respond_to?(:texture) ? env.texture : nil
        
        if texture
            # On tente d'extraire l'image
            ext = '.png' # Fallback par défaut
            if texture.respond_to?(:filename)
                f = texture.filename
                ext = File.extname(f) unless File.extname(f).empty?
            end
            
            dest = unique_path(safe_name, 'Environments', ext)
            
            if texture.respond_to?(:image_rep)
                texture.image_rep.save_file(dest)
            elsif texture.respond_to?(:write)
                texture.write(dest)
            end
        else
            # Si on ne peut pas extraire le fichier (ex: API limitée), 
            # on crée un fichier texte pour signaler sa présence et son nom dans le rapport
            dest = unique_path(safe_name, 'Environments', '.txt')
            File.open(dest, 'w') { |f| f.write("Environment detecté : #{env.name}\nImpossible d'extraire la source HDRI via l'API Ruby actuelle.\n") }
        end
      rescue => e
        puts "Erreur export environment #{safe_name} : #{e.message}"
      end
    end
  end

  def unique_path(base_name, subdir, extension)
    folder = File.join(@output, subdir)
    name   = "#{base_name}#{extension}"
    path   = File.join(folder, name)
    count  = 1
    while File.exist?(path)
      path = File.join(folder, "#{base_name}_#{count}#{extension}")
      count += 1
    end
    path
  end
end