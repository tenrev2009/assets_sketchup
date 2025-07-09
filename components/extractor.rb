# File: components/extractor.rb
require 'fileutils'

module ACA::Extractor
  extend self

  # Lance l'extraction des composants, groupes et textures
  #
  # @param extract_components [Boolean] – exporter les définitions de composants
  # @param extract_textures   [Boolean] – exporter les textures/images
  # @param extract_groups     [Boolean] – exporter les groupes de niveau racine
  # @param output_path        [String]  – dossier de destination
  def run(extract_components, extract_textures, extract_groups, output_path)
    @output = output_path
    FileUtils.mkdir_p(File.join(@output, 'Components'))
    FileUtils.mkdir_p(File.join(@output, 'Textures'))
    model = Sketchup.active_model

    export_components(model) if extract_components
    export_groups(model)     if extract_groups
    export_textures(model)   if extract_textures
  end

  # Exporte chaque définition de composant racine en .skp
  def export_components(model)
    defs = model.entities
                .grep(Sketchup::ComponentInstance)
                .map(&:definition)
                .uniq

    defs.each_with_index do |defn, idx|
      base     = defn.name.strip.empty? ? "Component_#{idx}" : defn.name
      safe     = base.gsub(/[\/\\:\*\?"<>\|]/, '_')
      dest     = unique_path(safe, 'Components', '.skp')
      begin
        success = defn.save_as(dest)
        UI.messagebox("Échec de la sauvegarde #{safe}") unless success
      rescue => e
        UI.messagebox("Erreur export component #{safe} : #{e.message}")
      end
    end
  end

  # Exporte chaque groupe de niveau racine en .skp
  def export_groups(model)
    groups = model.entities.grep(Sketchup::Group)
    groups.each_with_index do |grp, idx|
      defn = grp.definition
      base = defn.name.strip.empty? ? "Group_#{idx}" : defn.name
      safe = base.gsub(/[\/\\:\*\?"<>\|]/, '_')
      dest = unique_path(safe, 'Components', '.skp')
      begin
        success = defn.save_as(dest)
        UI.messagebox("Échec de la sauvegarde #{safe}") unless success
      rescue => e
        UI.messagebox("Erreur export group #{safe} : #{e.message}")
      end
    end
  end

  # Extrait toutes les textures de matériaux et images importées
  def export_textures(model)
    items = []

    # Textures appliquées aux matériaux
    model.materials.each do |mat|
      items << mat.texture if mat.texture
    end
    # Images importées dans le modèle
    model.entities.grep(Sketchup::Image).each do |img|
      items << img
    end

    items.uniq.each_with_index do |item, idx|
      begin
        src = item.respond_to?(:filename) ? item.filename : nil
        ext = File.extname(src.to_s).downcase
        ext = '.png' if ext.empty?
        base = File.basename(src.to_s, ext)
        safe = base.strip.empty? ? "Texture_#{idx}" : base
        safe = safe.gsub(/[\/\\:\*\?"<>\|]/, '_')
        dest = unique_path(safe, 'Textures', ext)

        if item.respond_to?(:write)
          item.write(dest)
        elsif src && File.exist?(src)
          FileUtils.cp(src, dest)
        else
          data = item.image_rep.to_png_data rescue nil
          if data
            File.open(dest, 'wb') { |f| f.write(data) }
          else
            UI.messagebox("Impossible d'exporter texture/image ##{idx}")
          end
        end
      rescue => e
        UI.messagebox("Erreur export texture/image #{safe} : #{e.message}")
      end
    end
  end

  # Génère un chemin unique dans @output/<subdir> pour éviter les doublons
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
