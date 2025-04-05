from flask import Flask, render_template, send_from_directory, abort
import os
from datetime import datetime
import json
import csv

app = Flask(__name__)

# Charger tous les fichiers
def load_all_files():
    files = []
    root_path = r'C:\Users\HP\Desktop\Revoir-Histoire-Anciens-Batisseurs-master'
    
    # Parcourir tous les fichiers du projet
    for dirpath, dirnames, filenames in os.walk(root_path):
        # Ignorer certains dossiers
        if 'web_interface' in dirpath or '.git' in dirpath:
            continue
            
        for filename in filenames:
            full_path = os.path.join(dirpath, filename)
            rel_path = os.path.relpath(full_path, root_path)
            
            # Déterminer la catégorie
            category = "Other"
            if 'data\\maps' in dirpath: category = "Maps"
            elif 'data\\sources' in dirpath: category = "Sources"
            elif 'Donnees_Lien_URL' in dirpath: category = "Links"
            elif 'docs' in dirpath: category = "Documents"
            elif 'scripts' in dirpath: category = "Scripts"
            
            # Obtenir les métadonnées
            stat = os.stat(full_path)
            file_ext = os.path.splitext(filename)[1][1:].lower() if os.path.splitext(filename)[1] else "unknown"
            
            files.append({
                "Name": filename,
                "Path": rel_path.replace('\\', '/'),
                "Category": category,
                "Type": file_ext,
                "Size": f"{round(stat.st_size / 1024, 2)} Ko",
                "Modified": datetime.fromtimestamp(stat.st_mtime).strftime("%d/%m/%Y %H:%M")
            })
    
    return files

# Routes
@app.route('/')
def index():
    return render_template('index.html', files=load_all_files())

@app.route('/category/<category>')
def show_category(category):
    files = [f for f in load_all_files() if f["Category"].lower() == category.lower()]
    return render_template('category.html', category=category, files=files)

@app.route('/view/<path:filepath>')
def view_file(filepath):
    root_path = r'C:\Users\HP\Desktop\Revoir-Histoire-Anciens-Batisseurs-master'
    full_path = os.path.join(root_path, filepath)
    
    if not os.path.exists(full_path):
        abort(404)
    
    # Trouver le fichier dans la liste
    file_data = next((f for f in load_all_files() if f["Path"] == filepath), None)
    if not file_data:
        abort(404)
    
    # Lire le contenu selon le type de fichier
    content = ""
    processed_content = None
    
    try:
        if file_data["Type"] == "json":
            with open(full_path, "r", encoding="utf-8") as f:
                content = json.load(f)
                
        elif file_data["Type"] == "csv":
            with open(full_path, "r", encoding="utf-8") as f:
                content = list(csv.DictReader(f))
                
        elif file_data["Type"] in ["txt", "md"]:
            with open(full_path, "r", encoding="utf-8") as f:
                content = f.read()
                
        elif file_data["Type"] in ["jpg", "jpeg", "png", "webp"]:
            content = None  # Les images sont gérées directement dans le template
                
    except Exception as e:
        content = f"[Erreur de lecture: {str(e)}]"
    
    return render_template('view_file.html', 
                         file=file_data, 
                         content=content)

@app.route('/download/<path:filepath>')
def download_file(filepath):
    root_path = r'C:\Users\HP\Desktop\Revoir-Histoire-Anciens-Batisseurs-master'
    full_path = os.path.join(root_path, filepath)
    
    if not os.path.exists(full_path):
        abort(404)
        
    return send_from_directory(
        os.path.dirname(full_path),
        os.path.basename(full_path),
        as_attachment=True
    )

if __name__ == '__main__':
    app.run(port=5000, debug=True)
