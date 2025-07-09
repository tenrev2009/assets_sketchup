# File: components/reporter.rb
require 'csv'

module ACA::Reporter
  extend self

  # Génère le rapport et le CSV à partir des dossiers Components/ et Textures/
  # Taille en Mo arrondie à 2 décimales dans le CSV
  # Retourne un hash contenant :
  #  - :summary => { total_items, total_bytes }
  #  - :items   => array de { name, type, size_bytes, size_mo, path }
  #  - :csv     => chemin du fichier CSV généré
  def generate(output_path)
    items = []

    # Parcours des deux sous-dossiers
    %w[Components Textures].each do |subdir|
      Dir.glob(File.join(output_path, subdir, '*')).each do |file|
        next unless File.file?(file)
        size_bytes = File.size(file)
        size_mo    = (size_bytes.to_f / 1024.0 / 1024.0).round(2)
        items << {
          name:       File.basename(file),
          type:       subdir.chomp('s'),     # "Component" ou "Texture"
          size_bytes: size_bytes,
          size_mo:    size_mo,
          path:       "#{subdir}/#{File.basename(file)}"
        }
      end
    end

    # Création du fichier CSV avec taille en Mo
    csv_path = File.join(output_path, "rapport_assets_#{Time.now.strftime('%Y%m%d')}.csv")
    CSV.open(csv_path, 'wb') do |csv|
      csv << %w[NOM TYPE TAILLE_MO CHEMIN_RELATIF]
      items.each do |r|
        csv << [r[:name], r[:type], r[:size_mo], r[:path]]
      end
    end

    # Retourne la structure du rapport
    {
      summary: {
        total_items: items.size,
        total_bytes: items.sum { |r| r[:size_bytes] }
      },
      items: items,
      csv:   csv_path
    }
  end
end




