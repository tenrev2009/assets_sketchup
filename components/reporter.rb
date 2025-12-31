# File: components/reporter.rb
require 'csv'

module ACA::Reporter
  extend self

  def generate(output_path)
    items = []

    # Ajout de 'Environments' à la liste
    %w[Components Textures Environments].each do |subdir|
      dir_path = File.join(output_path, subdir)
      next unless Dir.exist?(dir_path) # Sécurité si le dossier n'est pas créé

      Dir.glob(File.join(dir_path, '*')).each do |file|
        next unless File.file?(file)
        size_bytes = File.size(file)
        size_mo    = (size_bytes.to_f / 1024.0 / 1024.0).round(2)
        items << {
          name:       File.basename(file),
          type:       subdir.chomp('s'), # "Environment", "Component", etc.
          size_bytes: size_bytes,
          size_mo:    size_mo,
          path:       "#{subdir}/#{File.basename(file)}"
        }
      end
    end

    csv_path = File.join(output_path, "rapport_assets_#{Time.now.strftime('%Y%m%d_%H%M%S')}.csv")
    CSV.open(csv_path, 'wb') do |csv|
      csv << %w[NOM TYPE TAILLE_MO CHEMIN_RELATIF]
      items.each do |r|
        csv << [r[:name], r[:type], r[:size_mo], r[:path]]
      end
    end

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