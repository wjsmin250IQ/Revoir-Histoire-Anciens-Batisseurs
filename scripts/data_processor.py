# scripts/data_processor.py
import json
from pathlib import Path
import pandas as pd

def convert_legacy_files():
    # Chemins des fichiers
    youtube_file = Path("Donnees_Lien URL/Donnees_Lien_URL_YouTube.txt")
    output_file = Path("data/sources/youtube.json")
    
    # Conversion
    if youtube_file.exists():
        with open(youtube_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extraction des données (adaptée à votre format original)
        videos = []
        for line in content.split('\n'):
            if line.startswith('http'):
                videos.append({
                    "url": line.strip('"'),
                    "status": "unprocessed"
                })
        
        # Structure finale
        output_data = {
            "metadata": {
                "original_file": youtube_file.name,
                "conversion_date": pd.Timestamp.now().isoformat()
            },
            "videos": videos
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=2, ensure_ascii=False)

if __name__ == "__main__":
    convert_legacy_files()
    

def process_all_data():
    # Traitement des liens
    convert_legacy_files()
    
    # Traitement des cartes
    from map_processor import process_maps
    process_maps()
    
    # Vérification des liens
    from link_checker import check_all_links
    check_all_links()