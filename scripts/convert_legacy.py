import argparse
import json
import os

def convert_data(input_file, output_file, platform):
    """Convertit un fichier texte contenant des liens en JSON selon la plateforme spécifiée."""
    data = []
    
    try:
        with open(input_file, 'r', encoding='utf-8') as infile:
            for line in infile:
                line = line.strip()
                if line:
                    data.append({"platform": platform, "url": line})
        
        with open(output_file, 'w', encoding='utf-8') as outfile:
            json.dump(data, outfile, indent=4, ensure_ascii=False)
        print(f"Conversion réussie : {output_file}")
    except FileNotFoundError:
        print(f"Erreur : Le fichier {input_file} n'existe pas.")
    except Exception as e:
        print(f"Erreur lors de la conversion : {e}")

def main():
    parser = argparse.ArgumentParser(description="Convertisseur de données héritées en JSON")
    parser.add_argument("-i", "--input", required=True, help="Fichier source contenant les données")
    parser.add_argument("-o", "--output", required=True, help="Fichier JSON de sortie")
    parser.add_argument("-t", "--type", required=True, choices=["youtube", "web"], help="Type de données à convertir")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.input):
        print(f"Erreur : Le fichier d'entrée {args.input} n'existe pas.")
        return
    
    platform_map = {"youtube": "YouTube", "web": "Web"}
    convert_data(args.input, args.output, platform_map[args.type])

if __name__ == "__main__":
    main()
