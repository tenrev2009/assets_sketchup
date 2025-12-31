# File: components/ui.rb
require 'json'
require 'fileutils'

module ACA::UI
  extend self

  def launch
    @dlg = UI::HtmlDialog.new(
      title:           'Asset Collector & Analyzer',
      width:           600,
      height:          500,
      style:           UI::HtmlDialog::STYLE_DIALOG,
      preferences_key: 'ACA.Settings'
    )
    @dlg.set_html(html_content)

    @dlg.add_action_callback('select_directory') do |_ctx, _|
      dir = UI.select_directory(title: 'Choisir dossier de destination')
      if dir && !dir.empty?
        safe = dir.gsub('\\', '\\\\')
        @dlg.execute_script("document.getElementById('path').value = '#{safe}';")
      end
    end

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
        opts['extract_environments'],
        out
      )

      # Rapport
      rpt = ACA::Reporter.generate(out)

      # Nettoyage optionnel
      if opts['clear_assets']
        %w[Components Textures Environments].each do |sub|
          FileUtils.rm_rf(File.join(out, sub))
        end
      end

      @dlg.execute_script("showReport(#{rpt.to_json});")
    end

    # --- C'est ici que j'ai amélioré la logique de sélection ---
    @dlg.add_action_callback('select_asset') do |_ctx, target_name|
      model = Sketchup.active_model
      model.selection.clear
      found_def = nil
      instance_count = 0

      # On cherche la définition qui correspond au nom de fichier "nettoyé"
      model.definitions.each do |d|
        # On reproduit la logique de nettoyage de l'extracteur pour comparer
        real_name = d.name.to_s.strip
        # Si le nom est vide (ex: groupe sans nom), c'est dur à matcher via le nom de fichier générique
        next if real_name.empty? 

        safe_name = real_name.gsub(/[\/\\:\*\?"<>\|]/, '_')
        
        if safe_name == target_name
          found_def = d
          break
        end
      end

      if found_def
        found_def.instances.each do |i|
          model.selection.add(i)
          instance_count += 1
        end
        
        # Feedback utilisateur crucial
        if instance_count > 0
          # Optionnel : Zoomer sur la sélection pour voir où c'est
          # UI.messagebox("#{instance_count} instance(s) sélectionnée(s).")
        else
          UI.messagebox("L'élément '#{target_name}' est bien dans le fichier (Bibliothèque), mais il n'y a AUCUNE instance placée dans la scène.\n\nC'est un 'Composant Fantôme' qui prend de la place pour rien.\nConseil : Allez dans Statistiques > Purger les éléments inutilisés.")
        end
      else
        UI.messagebox("Impossible de retrouver l'asset '#{target_name}' dans le modèle.\n(Peut-être un Groupe sans nom ou renommage complexe).")
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
    body { font-family: sans-serif; margin:10px; font-size: 13px; }
    input[type=text] { width:65%; padding:4px; }
    button { padding:6px 10px; cursor:pointer; }
    .controls { background: #f0f0f0; padding: 10px; border-radius: 4px; margin-bottom: 10px; }
    table { width:100%; border-collapse:collapse; margin-top:10px; font-size: 12px; }
    th, td { border:1px solid #ccc; padding:4px 6px; text-align:left; }
    th { background:#eee; position: sticky; top: 0; }
    tr:nth-child(even) { background: #fafafa; }
    tr:hover { background: #e8f4ff; }
    a.select-link { color:#0078d7; text-decoration:underline; cursor:pointer; font-weight:bold; }
    a.select-link:hover { color:#005a9e; }
    .size-col { text-align: right; }
  </style>
</head>
<body>
  <h3>Asset Analyzer & Cleaner v1.2</h3>
  
  <div class="controls">
    <label>Dossier d'export :</label><br>
    <input id="path" type="text" readonly/>
    <button onclick="sketchup.select_directory()">...</button>
    <br><br>
    <div style="display:grid; grid-template-columns: 1fr 1fr;">
      <label><input type="checkbox" id="comp" checked/> Composants</label>
      <label><input type="checkbox" id="env" checked/> Environnements</label>
      <label><input type="checkbox" id="tex" checked/> Textures</label>
      <label><input type="checkbox" id="grp" /> Groupes</label>
    </div>
    <br>
    <label><input type="checkbox" id="clear" checked/> Supprimer les fichiers exportés après analyse</label>
    <br><br>
    <button onclick="start()" style="width:100%; font-weight:bold;">LANCER L'ANALYSE</button>
  </div>

  <div id="report"></div>

  <script>
    function start() {
      document.getElementById('report').innerHTML = '<em>Analyse en cours... cela peut prendre un moment...</em>';
      sketchup.start(JSON.stringify({
        output_path:        document.getElementById('path').value,
        extract_components: document.getElementById('comp').checked,
        extract_textures:   document.getElementById('tex').checked,
        extract_groups:     document.getElementById('grp').checked,
        extract_environments: document.getElementById('env').checked,
        clear_assets:       document.getElementById('clear').checked
      }));
    }

    function showReport(r) {
      var html = '<h4>Résumé</h4>' +
                 '<p><b>Total assets :</b> ' + r.summary.total_items + ' | ' +
                 '<b>Poids total :</b> ' + (r.summary.total_bytes/1024/1024).toFixed(2) + ' Mo</p>' +
                 '<p><a href="file://' + r.csv + '">Ouvrir le CSV complet</a></p>' +
                 '<table>' +
                   '<tr>' +
                     '<th>Nom</th>' +
                     '<th>Type</th>' +
                     '<th class="size-col">Taille (Mo)</th>' +
                     '<th>Action</th>' +
                   '</tr>';

      // Tri par taille décroissante
      r.items.sort(function(a, b) { return b.size_mo - a.size_mo; });

      r.items.forEach(function(item) {
        var baseName = item.name.replace(/\.[^/.]+$/, ''); // Enlève l'extension pour le matching
        
        // Logique d'affichage du lien
        var actionLink = '';
        if (item.type === 'Component' || item.type === 'Group') {
             actionLink = '<a class="select-link" onclick="selectAsset(\\'' + baseName + '\\')">Sélectionner</a>';
        } else if (item.type === 'Environment') {
             actionLink = '<span style="color:#888; font-style:italic;">(Voir onglet Env)</span>';
        } else {
             actionLink = '-';
        }

        html += '<tr>' +
                '<td>' + item.name + '</td>' +
                '<td>' + item.type + '</td>' +
                '<td class="size-col">' + item.size_mo.toFixed(2) + '</td>' +
                '<td>' + actionLink + '</td>' +
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