#!/usr/bin/env python3
"""Aggiunge le regole Karabiner (F5 -> keepawake-toggle, F4 -> maccy-trigger)
al profilo Karabiner attivo.

Idempotente: riconosce una regola gia' installata dallo shell_command, non
dalla descrizione (la descrizione la puoi cambiare, il comando no).
Con --check non scrive niente (exit 1 se una regola manca).
"""
import json
import os
import shutil
import sys
from datetime import datetime

HOME = os.path.expanduser("~")
KARABINER = os.path.join(HOME, ".config", "karabiner", "karabiner.json")

# (file regola nel repo, basename del comando installato)
REGOLE = [
    (os.path.join(os.path.dirname(os.path.abspath(__file__)),
                  "..", "f6-toggle", "karabiner-f5.json"),
     "keepawake-toggle"),
    (os.path.join(os.path.dirname(os.path.abspath(__file__)),
                  "..", "f4-maccy", "karabiner-f4-maccy.json"),
     "maccy-trigger"),
]

CHECK = "--check" in sys.argv


def contiene_comando(nodo, basename):
    """Cerca ricorsivamente il nostro shell_command dentro una regola."""
    if isinstance(nodo, dict):
        if nodo.get("shell_command", "").endswith(basename):
            return True
        return any(contiene_comando(v, basename) for v in nodo.values())
    if isinstance(nodo, list):
        return any(contiene_comando(v, basename) for v in nodo)
    return False


def carica_regola(path, basename):
    """Carica il file regola e sostituisce il placeholder col percorso vero."""
    with open(path) as f:
        regola = json.load(f)
    comando = os.path.join(HOME, ".local", "bin", basename)
    for m in regola.get("manipulators", []):
        for azione in m.get("to", []):
            if "shell_command" in azione:
                azione["shell_command"] = comando
    return regola


def main():
    if not os.path.exists(KARABINER):
        print("  karabiner.json non trovato: apri Karabiner-Elements almeno una volta")
        return 1

    with open(KARABINER) as f:
        conf = json.load(f)

    profili = conf.get("profiles", [])
    if not profili:
        print("  nessun profilo Karabiner nel file")
        return 1
    profilo = next((p for p in profili if p.get("selected")), profili[0])
    regole = profilo.setdefault("complex_modifications", {}).setdefault("rules", [])

    mancanti = []
    for path, basename in REGOLE:
        if any(contiene_comando(r, basename) for r in regole):
            print(f"  regola {basename}: gia' presente, non tocco niente")
            continue
        mancanti.append((path, basename))

    if not mancanti:
        return 0

    for path, basename in mancanti:
        print(f"  {'manca' if CHECK else 'aggiungo'}: {basename} nel profilo \"{profilo.get('name')}\"")

    if CHECK:
        return 1

    for path, basename in mancanti:
        regole.append(carica_regola(path, basename))

    backup = f"{KARABINER}.bak-keepawake-{datetime.now():%Y%m%d-%H%M%S}"
    shutil.copy2(KARABINER, backup)
    print(f"  backup: {backup}")

    tmp = KARABINER + ".tmp"
    with open(tmp, "w") as f:
        json.dump(conf, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, KARABINER)
    print(f"  scritto: {KARABINER} (Karabiner ricarica da solo)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
