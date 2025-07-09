# File: components/ui.rb
require 'json'
require 'fileutils'

module ACA::UI
  extend self

  def launch
    @dlg = UI::HtmlDialog.new(
      title:           'Asset Collector & Analyzer',
      width:           600,
      height:          400,
      style:           UI::HtmlDialog::STYLE_DIALOG,
      preferences_key: 'ACA.Settings'
    )
    @dlg.set_html(html_content)

    # Choix du dossier
    @dlg.add_action_callback('select_directory') do |_ctx, _|
      dir = UI.select_directory(title: 'Choisir dossier de destination')
      if dir && !dir.empty?
        safe = dir.gsub('\\', '\\\\')
        @dlg.execute_script("document.getElementById('path').value = '#{safe}';")
      end
    end

    # Lancement de l’extraction
    @dlg.add_action_callback('start') do |_ctx, jsonp|
      opts = JSON.parse(jsonp) rescue {}
      out  = opts['output_path']
      if out.to_s.empty?
        UI.messagebox('Veuillez choisir un dossier de destination.')
        next
      end

      # Extraction
      ACA::Extractor.run(
        opts['extract_components'],
        opts['extract_textures'],
        opts['extract_groups'],
        out
      )

      # Rapport (CSV inclus)
      rpt = ACA::Reporter.generate(out)

      # Suppression éventuelle des dossiers
      if opts['clear_assets']
        FileUtils.rm_rf(File.join(out, 'Components'))
        FileUtils.rm_rf(File.join(out, 'Textures'))
      end

      # Affichage du rapport
      @dlg.execute_script("showReport(#{rpt.to_json});")
    end

    # Sélection dans la scène du composant ou groupe
    @dlg.add_action_callback('select_asset') do |_ctx, def_name|
      model = Sketchup.active_model
      model.selection.clear
      # Instances de composants
      model.definitions.each do |d|
        next unless d.name == def_name
        d.instances.each { |i| model.selection.add(i) }
      end
      # Instances de groupes
      model.entities.grep(Sketchup::Group).each do |g|
        model.selection.add(g) if g.definition.name == def_name
      end
    end

    @dlg.show
  end

  def html_content
    <<-HTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: sans-serif; margin:10px; }
    input[type=text] { width:70%; padding:4px; }
    button { padding:6px 10px; margin-left:4px; }
    table { width:100%; border-collapse:collapse; margin-top:12px; }
    th, td { border:1px solid #ccc; padding:6px; text-align:left; }
    th { background:#eee; }
    a.select-link { color:blue; text-decoration:underline; cursor:pointer; }
  </style>
</head>
<body>
  <h3>Asset Collector & Analyzer v1.0</h3>
  <label>Dossier de destination :</label><br>
  <input id="path" type="text" readonly/>
  <button onclick="sketchup.select_directory()">...</button><br><br>

  <input type="checkbox" id="comp" checked/> Extraire composants<br>
  <input type="checkbox" id="tex" checked/> Extraire textures<br>
  <input type="checkbox" id="grp" /> Extraire groupes<br><br>

  <input type="checkbox" id="clear" /> Supprimer Components & Textures après rapport<br><br>

  <button onclick="start()">Lancer l'extraction</button>
  <div id="report"></div>

  <script>
    function start() {
      sketchup.start(JSON.stringify({
        output_path:        document.getElementById('path').value,
        extract_components: document.getElementById('comp').checked,
        extract_textures:   document.getElementById('tex').checked,
        extract_groups:     document.getElementById('grp').checked,
        clear_assets:       document.getElementById('clear').checked
      }));
    }

    function showReport(r) {
      var html = '<h4>Résumé</h4>' +
                 '<p>Total assets : ' + r.summary.total_items + '</p>' +
                 '<p>Taille totale : ' + (r.summary.total_bytes/1024/1024).toFixed(2) + ' Mo</p>' +
                 '<p><a href="file://' + r.csv + '">Télécharger CSV</a></p>' +
                 '<h4>Détails des fichiers</h4>' +
                 '<table>' +
                   '<tr>' +
                     '<th>Nom</th>' +
                     '<th>Type</th>' +
                     '<th>Taille (Mo)</th>' +
                     '<th>Chemin Relatif</th>' +
                     '<th>Sélectionner</th>' +
                   '</tr>';

      // Tri descendant par taille (size_mo)
      r.items.sort(function(a, b) { return b.size_mo - a.size_mo; })
             .forEach(function(item) {
        var baseName = item.name.replace(/\.[^/.]+$/, '');
        var link = (item.type === 'Component' || item.type === 'Group')
          ? '<a class="select-link" onclick="selectAsset(\\'' + baseName + '\\')">Sélectionner</a>'
          : '';
        html += '<tr>' +
                '<td>' + item.name + '</td>' +
                '<td>' + item.type + '</td>' +
                '<td>' + item.size_mo.toFixed(2) + '</td>' +
                '<td>' + item.path + '</td>' +
                '<td>' + link + '</td>' +
               '</tr>';
      });

      html += '</table>';
      document.getElementById('report').innerHTML = html;
    }

    function selectAsset(name) {
      sketchup.select_asset(name);
    }
  </script>
</body>
</html>
    HTML
  end
end

