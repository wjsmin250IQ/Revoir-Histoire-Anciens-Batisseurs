# scripts/analyze.py
import yaml
from data_processor import process_all_sources
from api_integration import update_metadata
import sys
sys.path.append("C:/Users/HP/Desktop/Revoir-Histoire-Anciens-Batisseurs-master/scripts")




def main():
    # Chargement config
    with open('config/project_settings.yaml') as f:
        config = yaml.safe_load(f)
    
    # Traitement des données
    process_all_sources(config)
    
    # Mise à jour via APIs
    if config['api']['youtube']['enabled']:
        update_metadata()

if __name__ == "__main__":
    main()