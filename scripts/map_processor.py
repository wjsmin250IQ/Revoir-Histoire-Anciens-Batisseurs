# scripts/map_processor.py
import os
import json
from PIL import Image
import pytesseract

def process_maps():
    maps_dir = os.path.join('data', 'maps')
    metadata_path = os.path.join(maps_dir, 'metadata.json')
    
    with open(metadata_path, 'r+') as f:
        data = json.load(f)
        
        for map_item in data['maps']:
            img_path = os.path.join(maps_dir, map_item['new_location'])
            
            # Extraction métadonnées de base
            with Image.open(img_path) as img:
                map_item['metadata']['dimensions'] = f"{img.width}x{img.height}"
                map_item['metadata']['format'] = img.format
                
            # OCR pour les cartes avec texte
            if map_item['metadata'].get('needs_ocr', True):
                text = pytesseract.image_to_string(img_path, lang='fra+eng')
                map_item['analysis']['extracted_text'] = text[:500] + "..."  # Truncate
            
        f.seek(0)
        json.dump(data, f, indent=2)
        f.truncate()

if __name__ == "__main__":
    process_maps()