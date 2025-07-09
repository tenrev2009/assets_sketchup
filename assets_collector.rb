# File: assets_collector.rb
require 'sketchup.rb'
require 'fileutils'

# Définition du module racine pour éviter le NameError
module ACA
end

# Chargement des composants
require_relative 'components/extractor'
require_relative 'components/reporter'
require_relative 'components/ui'

# Ajout au menu Extensions
unless file_loaded?(__FILE__)
  UI.menu('Extensions')
    .add_item('Asset Collector & Analyzer') { ACA::UI.launch }
  file_loaded(__FILE__)
end



